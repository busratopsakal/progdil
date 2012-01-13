
require 'yaml'
require 'erb'

task :exam do


  Dir.foreach("_exams") do |folder|
    if not (folder == "." or folder == "..")
      config = YAML.load_file("_exams/" + folder)
      title = config['title']
      footer = config['footer']
      q = config['q']
      mylist = []
      j = 0   
      
      for i in q
      temporary = File.read("_includes/q/" +i)
      mylist[j]= temporary
      j= +1
  end

      fornow= ERB.new(File.read("_templates/exam.md.erb")).result(binding)
      f = File.open('fornow.md' , 'w') #yazılabilir olarak aç ve  f değişkenine ata
      f.write(fornow) 
      f.close()
     
      sh "markdown2pdf fornow.md -o  _includes/newfile/#{folder}"# fornow.md uzantılı dosyayı pdf'e çevirip newfile klasöründeki folder dosyasına attm
      sh "rm -f fornow.md"  # fornow.md uzantılı dosyayı sil

   end     
  end
end


task :fair do  
  Dir.foreach("_includes/newfile/") do |tidy|
    if not (tidy == "." or tidy == "..")
      sh "rm -f _includes/newfile/#{tidy}"  #bu dizin altındaki dosyaları sil
    end
  end
end

task :default => :exam


