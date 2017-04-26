####################################################################
# Extend the True and False singletons to include a passfail method
####################################################################

class TrueClass
    def passfail
        'PASS'
    end
end

class FalseClass
    def passfail
        'FAIL'
    end
end

class Hash
    def nested_each_pair
        each_pair do |k, v|
            if v.is_a?(Hash)
                v.nested_each_pair { |k, v| yield k, v }
            else
                yield(k, v)
            end
        end
    end
end
