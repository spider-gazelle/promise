class Object
  macro __check_if_promise__
    {% if @type.ancestors.includes?(::Promise) %}
      ret_actual = self.type_var
      -> { ret_actual }
    {% else %}
      -> { self }
    {% end %}
  end

  def __check_for_promise__
    __check_if_promise__
  end
end

class Exception
  property cause : Exception?
end
