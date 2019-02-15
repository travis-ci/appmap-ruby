# @appmap
class Main
  class << self
    # @appmap
    def sclass_function
    end
  end

  # @appmap
  def instance_function
  end
end

puts DATA.read
__END__
[
  {
    "name": "Main",
    "location": "$FIXTURE_DIR/function_within_class.rb:2",
    "children": [
      {
        "name": "sclass_function",
        "location": "$FIXTURE_DIR/function_within_class.rb:5",
        "type": "function",
        "class_name": "Main",
        "static": true
      },
      {
        "name": "instance_function",
        "location": "$FIXTURE_DIR/function_within_class.rb:10",
        "type": "function",
        "class_name": "Main",
        "static": false
      }
    ],
    "type": "class"
  }
]