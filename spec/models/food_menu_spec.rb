require 'rails_helper'

RSpec.describe ***REMOVED***Menu, type: :model do
  describe "associations" do
    it { expect(subject).to belong_to :food }
    it { expect(subject).to belong_to :***REMOVED*** }
  end

  describe "validations" do
    it { expect(subject).to validate_presence_of(:food_id) }
    it { expect(subject).to validate_numericality_of(:quantity).is_greater_than(0) }
  end
end
