module Statesman
  module Adapters
    module SequelQueries
      def self.included(base)
        base.instance_eval do
          extend(ClassMethods)

          one_to_many(transition_name)

          one_to_one(most_recent_transition_association_name,
                     class: transition_class,
                     conditions: { most_recent: true })

          dataset_module(DatasetMethods)
        end
      end

      def self.states_where(model, states)
        to_state_column = ::Sequel.qualify(model.most_recent_transition_association_name, :to_state)

        if states.include? model.initial_state.to_s
          ::Sequel.|({to_state_column => states}, {to_state_column => nil})
#            "#{model.most_recent_transition_association_name}.to_state IN ? OR #{
#              model.most_recent_transition_association_name}.to_state IS NULL"
        else
          ::Sequel.&({to_state_column => states}, ::Sequel.~(to_state_column: nil))
#          "#{model.most_recent_transition_association_name}.to_state IN ? AND #{
#             model.most_recent_transition_association_name}.to_state IS NOT NULL")
        end
      end

      module DatasetMethods
        def in_state(*states)
          association_left_join(model.most_recent_transition_association_name).
          where(SequelQueries.states_where(model, states.map!(&:to_s)))
        end

        def not_in_state(*states)
          association_left_join(model.most_recent_transition_association_name).
          exclude(SequelQueries.states_where(model, states.map!(&:to_s)))
        end

        def order_by_activity
          most_recent_transition = model.most_recent_transition_association_name
          association_left_join(model.most_recent_transition_association_name).
            order(::Sequel.desc(::Sequel.qualify(most_recent_transition, :updated_at)))
        end
      end

      module ClassMethods
        def transition_name
          @transition_name ||= transition_class.name.underscore.pluralize.to_sym
        end

        def most_recent_transition_association_name
          @most_recent_transition_association_name ||= :"most_recent_#{transition_name.to_s.singularize}"
        end
      end
    end
  end
end
