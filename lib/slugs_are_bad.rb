module SlugsAreBad  
  # Make this model act as a permalink without slugs. Takes the attribute to be used as a permalink and the attribute to generate the permalink from
  def slugs_are_bad(generate_from = :title, permalink_method = :permalink)
    include InstanceMethods
    ClassMethods.setup_slugs_are_bad self do
      self.permalink_method = permalink_method
      self.generate_from = generate_from
    end
  end
  
  module InstanceMethods
    # Override the to_param method so that we return the 
    def to_param
      param = self.send(self.class.permalink_method)
      param = self.id.to_s if param.nil? || param.include?('.')
      param
    end
    
    # Protected
    protected
    
    # Adds the permalink to the model as it is saved if it doesnt not exists already.
    # You could manually specify the permalink in which case it will not be generated and added.
    def save_permalink
      if self.class.method_defined?(self.class.permalink_method)
        send("#{self.class.permalink_method}=", escape(self.send(self.class.generate_from))) if send(self.class.permalink_method).blank?
      else
        raise "Permalink method not found #{self.class.permalink_method} for #{self.class.name}"
      end
    end
    
    # escapes the attribute that is being used as the permalink to place it into a useable form
    def escape(string)
      result = string.parameterize
      result.size.zero? ? random_permalink(string) : result
    rescue
      random_permalink(string)
    end
    
    # Generates a random permlink - this method was taken directly from an existing plugin
    def random_permalink(seed = nil)
      Digest::SHA1.hexdigest("#{seed}#{Time.now.to_s.split(//).sort_by {rand}}")
    end
  end
  
  module ClassMethods
    def self.setup_slugs_are_bad(klass)
      klass.extend self
      
      class << klass
        attr_accessor :permalink_method
        attr_accessor :generate_from
      end

      yield
    
      klass.class_eval do        
        # Protected
        protected
        
        # overide the find_one method - this isnt a direct class method so we do a class_eval
        def self.find_one(id_to_find, options)
          if is_old_style_id?(id_to_find)
            super(id_to_find, options)
          else
            item = self.send("find_by_#{self.permalink_method}", id_to_find)
            raise ActiveRecord::RecordNotFound,
              "Error finding #{self.class.name} with #{self.permalink_method} #{id_to_find} (#{id_to_find.class.name})" if item.nil?
            item
          end
        end
        
        # Checks to see if this is the old style id (a number) is there a better way to do this?
        def self.is_old_style_id?(id_to_find)
          id_to_find.is_a?(Fixnum) || id_to_find.is_a?(Bignum) || id_to_find.to_s =~ /^\s?[0-9]+$/
        end
        
        before_validation_on_create :save_permalink
        validates_presence_of self.permalink_method
        validates_uniqueness_of self.permalink_method
      end
    end
  end  
end