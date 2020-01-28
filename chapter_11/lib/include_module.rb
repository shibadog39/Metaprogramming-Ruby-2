module BaseGreetings
  def greet
    "hello by base"
  end
end

module SpecialGreetings
  def greet
    "#{super} & hello by special"
  end
end

class MyClass
  include BaseGreetings
  include SpecialGreetings
end
