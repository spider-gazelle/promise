class Object
  macro __check_if_promise__
    {% if @type.ancestors.includes?(::Promise) %}
      self.type_var
    {% else %}
      self
    {% end %}
  end

  # NOTE:: Used by Promise::Generic
  def __check_for_promise__
    __check_if_promise__
  end
end

class Exception
  property cause : Exception?
end
