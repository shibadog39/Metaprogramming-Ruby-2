require 'active_model'
class User
  include ActiveModel::Validations
  attr_accessor :password

  validate do
    errors.add(:base, "Don't let dad choose the password.") if password == '1234'
  end
end
