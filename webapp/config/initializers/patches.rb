#fix for JSON gem/activesupport bug. More info: http://stackoverflow.com/questions/683989/how-do-you-deal-with-the-conflict-between-activesupportjson-and-the-json-gem
if defined?(ActiveSupport::JSON)
  [Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
    klass.class_eval do
      def to_json(*args)
        super(args)
      end
      def as_json(*args)
        super(args)
      end
    end
  end
end