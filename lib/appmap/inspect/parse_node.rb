require 'appmap/feature'

module AppMap
  module Inspect
    # ParseNodeStruct wraps a generic AST parse node.
    ParseNodeStruct = Struct.new(:node, :file_path, :ancestors) do
    end

    # ParseNode wraps a generic AST parse node.
    class ParseNode < ParseNodeStruct
      extend Forwardable

      def_delegators :node, :type, :location

      class << self
        # Build a ParseNode from an AST node.
        def from_node(node, file_path, ancestors)
          case node.type
          when :class
            ClassParseNode.new(node, file_path, ancestors.dup)
          when :def
            InstanceMethodParseNode.new(node, file_path, ancestors.dup)
          when :defs
            StaticMethodParseNode.new(node, file_path, ancestors.dup)
          end
        end
      end

      def public?
        true
      end

      # Gets the AST node of the module or class which encloses this node.
      def enclosing_type_node
        ancestors.reverse.find do |a|
          %i[class module].include?(a.type)
        end
      end

      def parent_node
        ancestors[-1]
      end

      def preceding_sibling_nodes
        index_of_this_node = parent_node.children.index { |c| c == node }
        parent_node.children[0...index_of_this_node]
      end

      protected

      def extract_class_name(node)
        node.children[0].children[1].to_s
      end

      def extract_module_name(node)
        node.children[0].children[1].to_s
      end
    end

    # A Ruby class.
    class ClassParseNode < ParseNode
      def to_feature(attributes)
        AppMap::Feature::Cls.new(extract_class_name(node), "#{file_path}:#{location.line}", attributes, [])
      end
    end

    # Abstract representation of a method.
    class MethodParseNode < ParseNode
      def to_feature(attributes)
        AppMap::Feature::Method.new(name, "#{file_path}:#{location.line}", attributes, []).tap do |a|
          a.static = static?
          a.class_name = class_name
        end
      end

      def enclosing_names
        ancestors.select do |a|
          %i[class module].include?(a.type)
        end.map do |a|
          send("extract_#{a.type}_name", a)
        end
      end
    end

    # A method defines as a :def AST node.
    class InstanceMethodParseNode < MethodParseNode
      def name
        node.children[0].to_s
      end

      def class_name
        enclosing_names.join('::')
      end

      # An instance method defined in an sclass is a static method.
      def static?
        result = ancestors[-1].type == :sclass ||
          (ancestors[-1].type == :begin && ancestors[-2] && ancestors[-2].type == :sclass)
        !!result
      end

      def public?
        preceding_send = preceding_sibling_nodes
                         .reverse
                         .select { |n| n.respond_to?(:type) && n.type == :send }
                         .find { |n| %i[public protected private].member?(n.children[1]) }
        preceding_send.nil? || preceding_send.children[1] == :public
      end
    end

    # A method defines as a :defs AST node.
    # For example:
    #
    # class Main
    #   def Main.main_func
    #  end
    # end
    class StaticMethodParseNode < MethodParseNode
      def name
        node.children[1].to_s
      end

      def class_name
        case (defs_type = node.children[0].type)
        when :self
          class_name_from_enclosing_type
        when :const
          class_name_from_declaration
        else
          raise "Unrecognized 'defs' method type : #{defs_type.inspect}"
        end
      end

      def static?
        true
      end

      protected

      def class_name_from_enclosing_type
        enclosing_names.join('::')
      end

      def class_name_from_declaration
        ancestor_names = enclosing_names
        ancestor_names.pop
        ancestor_names << node.children[0].children[1]
        ancestor_names.join('::')
      end
    end
  end
end
