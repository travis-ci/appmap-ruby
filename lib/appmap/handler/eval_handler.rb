# frozen_string_literal: true

require 'appmap/handler/function_handler'

module AppMap
  module Handler
    # Handler class for Kernel#eval.
    #
    # Second argument to eval is a Binding, which despite the name (and
    # the accessible methods) in addition to locals and receiver also
    # encapsulates the entire execution context, in particular including
    # the lexical scope. This is especially important for constant lookup
    # and definition.
    #
    # If the binding is not provided, by default eval will run in the
    # current frame. Since we call it here, this will mean the #do_call
    # frame, which would make AppMap::Handler::EvalHandler the lexical scope
    # for constant lookup and definition; as a consequence
    # eg. `eval "class Foo; end"` would define
    # AppMap::Handler::EvalHandler::Foo instead of defining it in
    # the module where the original call was made.
    #
    # To avoid this, we explicitly substitute the correct execution
    # context, up several stack frames.
    class EvalHandler < FunctionHandler
      # Kernel#eval reports the method parameters as :rest, instead of what you might expect from
      # the documented signature: eval(string [, binding [, filename [,lineno]]])
      # In the C code, it's defined as rb_f_eval(int argc, const VALUE *argv, VALUE self),
      # so maybe that's why the parameters are reported as :rest.
      #
      # In any case, reporting the parameters as :rest means that the code string, binding, etc
      # are reported in the AppMap as members of an Array, without individual object ids or types.
      #
      # To make eval easier to analyze, fake the hook_method parameters to better match
      # the documentation.
      PARAMETERS= [
        [ :req, :string ],
        [ :rest ],
      ]

      # The depth of the frame we need to pluck out:
      # 1. Hook::Method#do_call
      # 2. Hook::Method#trace_call
      # 3. Hook::Method#call
      # 4. proc generated by Hook::Method#hook_method_def
      # 5. the (intended) frame of the original eval that we hooked
      # Note it needs to be adjusted if this call sequence changes.
      FRAME_DEPTH = 5
  
      def handle_call(receiver, args)
        AppMap::Event::MethodCall.build_from_invocation(defined_class, hook_method, receiver, args, parameters: PARAMETERS)
      end

      def do_call(receiver, src = nil, context = nil, *rest)
        context ||= AppMap.caller_binding FRAME_DEPTH
        hook_method.bind(receiver).call(src, context, *rest)
      end
    end
  end
end
