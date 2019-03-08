module Api
  module V2
    class DailyFrequencyStudentsController < Api::V2::BaseController
      respond_to :json

      def update
        daily_frequency_student = DailyFrequencyStudent.find(params[:id])
        daily_frequency_student.update(present: params[:present], active: true)

        respond_with daily_frequency_student
      end

      def update_or_create
        creator = DailyFrequenciesCreator.new(
          unity: unity,
          classroom_id: params[:classroom_id],
          frequency_date: params[:frequency_date],
          class_numbers: [params[:class_number]],
          discipline_id: params[:discipline_id],
          school_calendar: current_school_calendar,
          period: period
        )
        creator.find_or_create!

        daily_frequency = creator.daily_frequencies[0]

        if daily_frequency
          daily_frequency_student = DailyFrequencyStudent.find_or_create_by(
            daily_frequency_id: daily_frequency.id,
            student_id: params[:student_id],
            active: true
          )

          daily_frequency_student.update(present: params[:present])

          respond_with daily_frequency_student
        else
          render json: []
        end
      end

      def current_user
        User.find(user_id)
      end

      protected

      def user_id
        @user_id ||= params[:user_id] || 1
      end

      def classroom
        @classroom ||= Classroom.find_by(id: params[:classroom_id])
      end

      def unity
        @unity ||= classroom.unity
      end

      def current_school_calendar
        @current_school_calendar ||= CurrentSchoolCalendarFetcher.new(unity, classroom).fetch
      end

      def period
        TeacherPeriodFetcher.new(
          params['teacher_id'],
          params['classroom_id'],
          params['discipline_id']
        ).teacher_period
      end
    end
  end
end
