require 'yaml'
require 'aws-sdk-ssm'

# This code is designed to mimic https://github.com/terrywbrady/yaml/blob/master/config.yml

class ConfigResolver
  @regex = "\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}"
  @ssm = Aws::SSM::Client.new

  def resolveValues(file)
    config = YAML.load_file(file)
    resolveValue(config)
  end

  # Walk the Hash object examining every value
  # Treat values containing {!ENV: key} or {!SSM: path} as special
  def resolveValue(obj)
    if obj.instance_of?(Hash)
      copy = Hash.new
      obj.each do |k, v|
        copy[k] = resolveValue(v)
      end
      copy
    elsif obj.instance_of?(Array)
      arr = Array.new
      obj.each do |v|
        arr.push(resolveValue(v))
      end
      arr
    elsif obj.instance_of?(String)
      val = obj
      m = obj.match(@regex)
      if m
        type, key, x, defval = m.captures
        key = key.strip if key
        defval = defval.strip if defval
        puts "#{type} #{key} #{defval}"
        val = defval if defval
        if type == 'ENV'
          val = ENV[key] if ENV.key?(key)
        elsif type == 'SSM'
          begin
            @ssm.get_parameter(name: key)[:parameter][:value]
          rescue
            puts "Cannot read SSM Parmeter #{key}"
          end
        end
      end
      val
    else
      obj
   end
  end
end
