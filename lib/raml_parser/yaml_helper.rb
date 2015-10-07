module RamlParser
  class YamlNode
    attr_reader :parent, :key, :value, :marks

    def initialize(parent, key, value)
      @parent = parent
      @key = key
      @value = value
      @marks = {}
    end

    def root
      if @parent != nil
        @parent.root
      else
        self
      end
    end

    def path
      if @parent != nil
        "#{@parent.path}.#{@key}"
      else
        @key
      end
    end

    def mark(what, p = path)
      if parent.nil?
        @marks[p] = what
      else
        @parent.mark(what, p)
      end
      self
    end

    def mark_all(what)
      mark(what)
      if @value.is_a? Hash
        hash_values { |n| n.mark_all(what) }
      elsif @value.is_a? Array
        array_values { |n| n.mark_all(what) }
      end
      self
    end

    def or_default(default)
      @value != nil ? self : YamlNode.new(@parent, @key, default)
    end

    def array(index)
      new_node = YamlNode.new(self, "[#{index}]", @value[index])
      new_node.mark(:used)
      new_node
    end

    def array_values(&code)
      (@value || []).each_with_index.map { |_,i| code.call(array(i)) }
    end

    def hash(key)
      new_node = YamlNode.new(self, key, @value[key])
      new_node.mark(:used)
      new_node
    end

    def hash_values(&code)
      Hash[(@value || {}).map { |k,v| [k, code.call(hash(k))] }]
    end

    def arrayhash(index)
      new_node = array(index)
      new_node.mark(:used)
      new_node2 = new_node.hash(new_node.value.first[0])
      new_node2.mark(:used)
      new_node2
    end

    def arrayhash_values(&code)
      Hash[(@value || []).each_with_index.map { |_,i|
        node = arrayhash(i)
        [node.key, code.call(node)]
      }]
    end
  end

  class YamlHelper
    require 'yaml'
    require 'open-uri'

    def self.root_path(path)
      if URI.parse(path)
        root = path.split('/')[0..-2].join('/')
      else
        root = File.dirname(path)
      end
      root
    end

    def self.base_name(path)
      if URI.parse(path)
        root = path.split('/')[-1]
      else
        root = File.basename(path)
      end
      root
    end

    def self.read_yaml(name, root, local)
      # add support for !include tags

      Psych.add_domain_type 'include', 'include' do |_, value|
        newpath = root + '/' + value
        newroot = root_path(newpath)
        newbase = base_name(newpath)
        if self.is_yaml?(newpath)
            read_yaml(newbase, newroot, local)
        else
            if local
              Dir.chdir(newroot)
              File.read(newbase)
            else
              open(root + '/' + value){ |f| f.read }
            end
        end
      end

        if local
          Dir.chdir(root)
          raw = File.read(name)
        else
          raw = open(root + '/' + name){ |f| f.read }
        end

     node = self.is_yaml?(name) ? YAML.load(raw) : raw

    end

    def self.dump_yaml(yaml)
      YAML.dump(yaml)
    end

    def self.is_yaml?(path)
      [ 'yaml', 'yml', 'raml' ].include? path.split('.').last.downcase
    end
  end
end
