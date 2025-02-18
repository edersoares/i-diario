class StudentEnrollmentClassroom < ActiveRecord::Base
  include Discardable
  include Audit
  audited
  has_associated_audits

  belongs_to :classrooms_grade
  belongs_to :student_enrollment

  has_enumeration_for :period, with: Periods, skip_validation: true

  attr_accessor :entity_id

  after_discard { StudentDependenciesDiscarder.discard(entity_id, student_id) }
  after_undiscard { StudentDependenciesDiscarder.undiscard(entity_id, student_id) }

  default_scope -> { kept }
  scope :by_discipline, lambda {|discipline_id| by_discipline_query(discipline_id)}
  scope :by_classroom, lambda { |classroom_id|
    joins(:classrooms_grade).where(classrooms_grades: { classroom_id: classroom_id })
  }
  scope :by_year, lambda { |year|
    joins(classrooms_grade: :classroom).merge(Classroom.by_year(year))
  }
  scope :by_date, lambda { |date|
    where("? >= joined_at AND (? < left_at OR coalesce(left_at, '') = '')", date.to_date, date.to_date)
  }
  scope :by_date_not_before, ->(date) { where.not('joined_at < ?', date.to_date) }
  scope :by_date_not_after, ->(date) { where("left_at IN (NULL, '') OR left_at > ?", date.to_date) }
  scope :by_score_type, lambda {|score_type, classroom_id| by_score_type_query(score_type, classroom_id)}
  scope :show_as_inactive, -> { where(show_as_inactive_when_not_in_date: 't') }
  scope :by_grade, ->(grade_id) { joins(:classrooms_grade).where(classrooms_grades: { grade_id: grade_id }) }
  scope :by_classroom_grade, ->(classrooms_grade_id) { where(classrooms_grades: classrooms_grade_id) }
  scope :by_student, ->(student_id) { joins(student_enrollment: :student).where(students: { id: student_id }) }
  scope :by_student_enrollment, ->(student_enrollment_id) { where(student_enrollment_id: student_enrollment_id) }
  scope :active, lambda {
    joins(:student_enrollment).where(student_enrollments: { active: IeducarBooleanState::ACTIVE })
  }
  scope :ordered, -> { order(:joined_at, :index) }
  scope :ordered_student, -> { joins(student_enrollment: :student).order('sequence ASC, students.name ASC') }
  scope :status_attending, -> { joins(:student_enrollment).merge(StudentEnrollment.status_attending) }
  delegate :student_id, to: :student_enrollment, allow_nil: true

  def self.by_date_range(start_at, end_at)
    where("(CASE
              WHEN COALESCE(student_enrollment_classrooms.left_at) = '' THEN
                student_enrollment_classrooms.joined_at <= :end_at
              ELSE
                student_enrollment_classrooms.joined_at <= :end_at AND
                student_enrollment_classrooms.left_at >= :start_at AND
                student_enrollment_classrooms.joined_at <> student_enrollment_classrooms.left_at
            END)", end_at: end_at.to_date, start_at: start_at.to_date)
  end

  def self.by_period(period)
    joins(classrooms_grade: :classroom).where(
      "CASE
         WHEN :period = 4 THEN
           TRUE
         WHEN CAST(classrooms.period AS INTEGER) = 4 AND :period = 1 THEN
           student_enrollment_classrooms.period <> 2 OR student_enrollment_classrooms.period IS NULL
         WHEN CAST(classrooms.period AS INTEGER) = 4 AND :period = 2 THEN
           student_enrollment_classrooms.period <> 1 OR student_enrollment_classrooms.period IS NULL
         ELSE
           COALESCE(student_enrollment_classrooms.period, CAST(classrooms.period AS INTEGER)) = :period
      END", period: period
    )
  end

  def self.by_discipline_query(discipline_id)
    unless discipline_id.blank?
      where("(not exists(select 1
                           from student_enrollment_dependences
                          where student_enrollment_dependences.student_enrollment_id = student_enrollments.id) OR
                  exists(select 1
                           from student_enrollment_dependences
                          where student_enrollment_dependences.student_enrollment_id = student_enrollments.id and
                                student_enrollment_dependences.discipline_id = ?))", discipline_id)
    end
  end

  def self.by_score_type_query(score_type, classroom_id)
    return where(nil) if score_type == StudentEnrollmentScoreTypeFilters::BOTH

    score_type = case score_type
                 when StudentEnrollmentScoreTypeFilters::CONCEPT then ScoreTypes::CONCEPT
                 else ScoreTypes::NUMERIC
                 end

    classrooms_grades = ClassroomsGrade.by_classroom_id(classroom_id).by_score_type(score_type)
    exam_rules = classrooms_grades.map(&:exam_rule)

    return where(nil) if exam_rules.blank?

    differentiated_exam_rules = exam_rules.map(&:differentiated_exam_rule).compact.presence || exam_rules

    allowed_score_types = [ScoreTypes::NUMERIC_AND_CONCEPT, score_type]

    exam_rule_included = exam_rules.any? { |exam_rule| allowed_score_types.include?(exam_rule.score_type) }
    differentiated_exam_rule_included = differentiated_exam_rules.any? { |differentiated_exam_rule|
      allowed_score_types.include?(differentiated_exam_rule.score_type)
    }

    scoped = where(student_enrollment_classrooms: { classrooms_grade_id: classrooms_grades.pluck(:id) })

    return scoped.where(nil) if exam_rule_included && differentiated_exam_rule_included
    return none unless exam_rule_included || differentiated_exam_rule_included

    scoped.joins(student_enrollment: :students).where(students: { uses_differentiated_exam_rule: differentiated_exam_rule_included })
  end
end
