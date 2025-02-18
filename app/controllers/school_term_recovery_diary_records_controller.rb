class SchoolTermRecoveryDiaryRecordsController < ApplicationController
  has_scope :page, default: 1
  has_scope :per, default: 10

  before_action :require_current_classroom
  before_action :require_current_teacher
  before_action :require_allow_to_modify_prev_years, only: [:create, :update, :destroy]

  def index
    step_id = (params[:filter] || []).delete(:by_step_id)

    @school_term_recovery_diary_records = apply_scopes(SchoolTermRecoveryDiaryRecord)
      .includes(
        recovery_diary_record: [
          :unity,
          :classroom,
          :discipline
        ]
      )
      .by_classroom_id(current_user_classroom)
      .by_discipline_id(current_user_discipline)
      .ordered

    if step_id.present?
      @school_term_recovery_diary_records = @school_term_recovery_diary_records.by_step_id(
        current_user_classroom,
        step_id
      )
      params[:filter][:by_step_id] = step_id
    end

    authorize @school_term_recovery_diary_records
  end

  def new
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.new.localized
    @school_term_recovery_diary_record.build_recovery_diary_record
    @school_term_recovery_diary_record.recovery_diary_record.unity = current_unity

    if current_test_setting.blank?
      flash[:error] = t('errors.avaliations.require_setting')

      redirect_to(school_term_recovery_diary_records_path)
    end

    return if performed?

    @number_of_decimal_places = current_test_setting.number_of_decimal_places
  end

  def create
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.new.localized
    @school_term_recovery_diary_record.assign_attributes(resource_params.to_h)
    @school_term_recovery_diary_record.step_number = @school_term_recovery_diary_record.step.try(:step_number)
    @school_term_recovery_diary_record.recovery_diary_record.teacher_id = current_teacher_id

    authorize @school_term_recovery_diary_record

    if @school_term_recovery_diary_record.save
      respond_with @school_term_recovery_diary_record, location: school_term_recovery_diary_records_path
    else
      @number_of_decimal_places = current_test_setting.number_of_decimal_places
      render :new
    end
  end

  def edit
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.find(params[:id]).localized
    step_number = @school_term_recovery_diary_record.step_number
    @school_term_recovery_diary_record.step_id = steps_fetcher.step(step_number).try(:id)

    if @school_term_recovery_diary_record.step_id.blank?
      recorded_at = @school_term_recovery_diary_record.recorded_at
      flash[:alert] = t('errors.general.calendar_step_not_found', date: recorded_at)

      return redirect_to school_term_recovery_diary_records_path
    end

    authorize @school_term_recovery_diary_record

    reload_students_list

    students_in_recovery = fetch_students_in_recovery
    mark_students_not_in_recovery_for_destruction(students_in_recovery)
    mark_exempted_disciplines(students_in_recovery)
    add_missing_students(students_in_recovery)

    @any_student_exempted_from_discipline = any_student_exempted_from_discipline?
    @number_of_decimal_places = current_test_setting.number_of_decimal_places
  end

  def update
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.find(params[:id]).localized
    @school_term_recovery_diary_record.assign_attributes(resource_params.to_h)
    @school_term_recovery_diary_record.recovery_diary_record.teacher_id = current_teacher_id
    @school_term_recovery_diary_record.recovery_diary_record.current_user = current_user

    authorize @school_term_recovery_diary_record

    if @school_term_recovery_diary_record.save
      respond_with @school_term_recovery_diary_record, location: school_term_recovery_diary_records_path
    else
      @number_of_decimal_places = current_test_setting.number_of_decimal_places
      reload_students_list
      render :edit
    end
  end

  def destroy
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.find(params[:id])

    @school_term_recovery_diary_record.recovery_diary_record.destroy

    respond_with @school_term_recovery_diary_record, location: school_term_recovery_diary_records_path
  end

    def history
    @school_term_recovery_diary_record = SchoolTermRecoveryDiaryRecord.find(params[:id])

    authorize @school_term_recovery_diary_record

    respond_with @school_term_recovery_diary_record
  end

  private

  def resource_params
    params.require(:school_term_recovery_diary_record).permit(
      :step_id,
      :recorded_at,
      recovery_diary_record_attributes: [
        :id,
        :unity_id,
        :classroom_id,
        :discipline_id,
        :recorded_at,
        students_attributes: [
          :id,
          :student_id,
          :score,
          :_destroy
        ]
      ]
    )
  end

  def steps_fetcher
    @steps_fetcher ||= StepsFetcher.new(current_user_classroom)
  end

  def test_setting
    @test_setting ||= TestSettingFetcher.current(current_user_classroom, @school_term_recovery_diary_record.step)
  end

  def decimal_places
    test_setting.number_of_decimal_places
  end
  helper_method :decimal_places

  def fetch_students_in_recovery
    StudentsInRecoveryFetcher.new(
      api_configuration,
      @school_term_recovery_diary_record.recovery_diary_record.classroom_id,
      @school_term_recovery_diary_record.recovery_diary_record.discipline_id,
      @school_term_recovery_diary_record.step_id,
      @school_term_recovery_diary_record.recorded_at
    ).fetch
  end

  def mark_students_not_in_recovery_for_destruction(students_in_recovery)
    @students.each do |student|
      is_student_in_recovery = students_in_recovery.any? do |student_in_recovery|
        student.student.id == student_in_recovery.id
      end

      student.mark_for_destruction unless is_student_in_recovery
    end
  end

  def mark_exempted_disciplines(students_in_recovery)
    @students.each do |student|
      exempted_from_discipline = students_in_recovery.find do |student_in_recovery|
        student_in_recovery.id == student.student_id
      end.try(:exempted_from_discipline)

      student.exempted_from_discipline = exempted_from_discipline
    end
  end

  def add_missing_students(students_in_recovery)
    students_missing = students_in_recovery.select do |student_in_recovery|
      @students.none? do |student|
        student.student.id == student_in_recovery.id
      end
    end

    students_missing.each do |student_missing|
      student = @school_term_recovery_diary_record.recovery_diary_record.students.build(student: student_missing)
      @students << student
    end
  end

  def any_student_exempted_from_discipline?
    @students.any?(&:exempted_from_discipline)
  end

  def api_configuration
    IeducarApiConfiguration.current
  end

  def fetch_student_enrollments
    recovery_diary_record = @school_term_recovery_diary_record.recovery_diary_record
    return unless recovery_diary_record.recorded_at

    StudentEnrollmentsList.new(
      classroom: recovery_diary_record.classroom,
      discipline: recovery_diary_record.discipline,
      score_type: StudentEnrollmentScoreTypeFilters::NUMERIC,
      date: recovery_diary_record.recorded_at,
      search_type: :by_date
    ).student_enrollments
  end

  def reload_students_list
    return unless (student_enrollments = fetch_student_enrollments)

    recovery_diary_record = @school_term_recovery_diary_record.recovery_diary_record

    return unless recovery_diary_record.recorded_at

    @students = []

    student_enrollments.each do |student_enrollment|
      next unless (student = Student.find_by(id: student_enrollment.student_id))

      recovery_student = recovery_diary_record.students.select { |student_recovery|
        student_recovery.student_id == student.id
      }.first
      note_student = recovery_student ||
                     recovery_diary_record.students.build(student: student)

      note_student.active = student_active_on_date?(student_enrollment, recovery_diary_record)

      @students << note_student
    end

    @students
  end

  def student_active_on_date?(student_enrollment, recovery_diary_record)
    StudentEnrollment.where(id: student_enrollment)
                     .by_classroom(recovery_diary_record.classroom)
                     .by_date(recovery_diary_record.recorded_at)
                     .any?
  end
end
