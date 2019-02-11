require 'spec_helper'

RSpec.describe PostingDateChecker, type: :service do
  let(:classroom) { create(:classroom) }
  let(:school_calendar) { create(:school_calendar, unity: classroom.unity) }
  let(:school_calendar_step) { create(:school_calendar_step, school_calendar: school_calendar) }

  let(:user) { create(:user_with_user_role) }

  before do
    User.current = create(:user_with_user_role)
    User.current.current_user_role = User.current.user_roles.first
  end

  subject do
    described_class.new(classroom, school_calendar_step.start_at)
  end

  context 'user current is nil' do
    before do
      User.current = nil
    end

    it { expect(subject.check).to be(true) }
  end

  context 'current thread origin is api' do
    before do
      Thread.current[:origin_type] = OriginTypes::API_V2
    end

    it { expect(subject.check).to be(true) }

    after do
      Thread.current[:origin_type] = nil
    end
  end

  context 'current user is admin' do
    before do
      User.current.admin = true
    end

    it { expect(subject.check).to be(true) }
  end

  context 'current user isnt admin' do
    before do
      User.current.admin = false
    end

    context 'permission is setted to post without restricitons' do
      before do
        permission = User.current
          .current_user_role
          .role
          .permissions
          .find_or_initialize_by(feature: Features::IEDUCAR_API_EXAM_POSTING_WITHOUT_RESTRICTIONS)

        permission.permission = Permissions::CHANGE
        permission.save!
      end

      it { expect(subject.check).to be(true) }
    end

    context 'permission isnt setted to post without restricitons' do
      before do
        permission = User.current
          .current_user_role
          .role
          .permissions
          .find_or_initialize_by(feature: Features::IEDUCAR_API_EXAM_POSTING_WITHOUT_RESTRICTIONS)

        permission.permission = Permissions::READ
        permission.save!
      end

      context 'current date is on posting period of record_date step' do
        before do
          school_calendar_step.update_attribute(:start_date_for_posting, Date.today)
          school_calendar_step.update_attribute(:end_date_for_posting, Date.today)
        end

        it { expect(subject.check).to be(true) }
      end

      context 'current date isnt on posting period of record_date step' do
        before do
          school_calendar_step.update_attribute(:start_date_for_posting, Date.today+1)
          school_calendar_step.update_attribute(:end_date_for_posting, Date.today+1)
        end

        it { expect(subject.check).to be(false) }
      end

      context 'record_date doest have a step' do
        subject do
          described_class.new(classroom, school_calendar_step.start_at-1)
        end

        it { expect(subject.check).to be(false) }
      end
    end
  end
end
