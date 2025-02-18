class AbsenceJustificationReportForm
  include ActiveModel::Model

  attr_accessor :unity_id,
                :classroom_id,
                :discipline_id,
                :absence_date,
                :absence_date_end,
                :school_calendar_year,
                :current_teacher_id,
                :user_id,
                :author

  validates :absence_date, presence: true, date: true, not_in_future: true, timeliness: {
    on_or_before: :absence_date_end,
    type: :date,
    on_or_before_message: :on_or_before_message
  }
  validates :absence_date_end, presence: true, date: true, not_in_future: true, timeliness: {
    on_or_after: :absence_date,
    type: :date,
    on_or_after_message: :on_or_after_message
  }
  validates :unity_id, presence: true
  validates :classroom_id, presence: true
  validates :discipline_id, presence: true, if: :frequence_type_by_discipline?

  validate :must_find_absence

  def absence_justifications
    @absence_justifications ||= AbsenceJustification.includes(:disciplines)
                                                    .includes(:students)
                                                    .by_unity(unity_id)
                                                    .by_school_calendar_report(school_calendar_year)
                                                    .by_classroom(classroom_id)
                                                    .by_date_range(absence_date, absence_date_end)

    if frequence_type_by_discipline?
      @absence_justifications = @absence_justifications.by_discipline_id(discipline_id)
    end

    @absence_justifications = @absence_justifications.by_author(author, user_id) if author.present?

    @absence_justifications.ordered.distinct
  end

  def frequence_type_by_discipline?
    frequency_type_definer = FrequencyTypeDefiner.new(classroom, current_teacher_id)
    frequency_type_definer.define!
    frequency_type_definer.frequency_type == FrequencyTypes::BY_DISCIPLINE
  end

  private

  def must_find_absence
    return if errors.present?

    errors.add(:base, 'Não foram encontrados resultados para a pesquisa!') if absence_justifications.blank?
  end

  def classroom
    Classroom.find(classroom_id) if classroom_id.present?
  end
end
