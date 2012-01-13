
require 'pathname' # require çağırma işlemini gerçekleştirir.
require 'pythonconfig' # bu komut pythondaki import gibidir.
require 'yaml'  # bu komut ile 'pathname', 'pythonconfig' ve 'yaml' modüllerini çağırıyoruz.

CONFIG = Config.fetch('presentation', {}) # Config.fetch ; varsa ilk argumandaki keye gore veriyi çeker.eğer veri yoksa ikinci argumanı 
					# geri dondurur(default değer olarak), presentation dizinindeki dosyayı alıyor.

PRESENTATION_DIR = CONFIG.fetch('directory', 'p') # PREENTATION_DIR'a p dizinin içeriğini aktarıyor.
DEFAULT_CONFFILE = CONFIG.fetch('conffile', '_templates/presentation.cfg')  # DEFAULT_CONFİLE'a presentation.cfg isimli config dosyasının içeriğini al
INDEX_FILE = File.join(PRESENTATION_DIR, 'index.html') #Join:birleştir komutu kullanılmıştır.Yani İndex_File a Presenation_dır ile 
                                                      #index.html'i birleştir.
IMAGE_GEOMETRY = [ 733, 550 ]   #  resim boyutları için belirlediğimiz öntanımlı değerler
DEPEND_KEYS    = %w(source css js) #parantezde verilen source css ve js bağımlı anahtarlar olarak belirledik 
DEPEND_ALWAYS  = %w(media) #  bağımlılık verilecek dizin; medya dizini
TASKS = {
    :index   => 'sunumları indeksle',  # verilen görev listesi ve açıklamaları
    :build   => 'sunumları oluştur',
    :clean   => 'sunumları temizle',
    :view    => 'sunumları görüntüle',
    :run     => 'sunumları sun',
    :optim   => 'resimleri iyileştir',
    :default => 'öntanımlı görev',
}

presentation   = {}  #sunum bilgilerini girmek için çırpı oluştur
tag            = {}  #etiketleri girmek için çırpı oluştur

class File  #File sınıfı oluşturuluyor.
  @@absolute_path_here = Pathname.new(Pathname.pwd)  #dosyayolunu statik bir değişkene atıyor.
  def self.to_herepath(path)  # bu fonksiyon verilen mutlak yolu goreceli yol haline getiriyor
    Pathname.new(File.expand_path(path)).relative_path_from(@@absolute_path_here).to_s 
  end
  def self.to_filelist(path)    # bu fonksiyon ise verilen yoldaki dosyaları sıralıyor
    File.directory?(path) ?     # dosya yolları aynı ise 
      FileList[File.join(path, '*')].select { |f| File.file?(f) } : # dosyaları listeliyor. bu ikisine de nesne olmadan erişilebiliyor.
      [path]
  end
end

def png_comment(file, string) #png_comment isimli file ve string isimli iki argümana sahip bir fonksiyon çağırıyor. 
  require 'chunky_png'#chunky_png modülünü çağırıyor.
  require 'oily_png' #oily_png dosyalarını çağırıyor.

  image = ChunkyPNG::Image.from_file(file) #burada resmi alıyor
  image.metadata['Comment'] = 'raked' #burada yorumluyor 
  image.save(file)  # ve bu dosyayı kaydediyor.
end

def png_optim(file, threshold=40000)  # png olan resimleri optimize ediyor
  return if File.new(file).size < threshold   #boyutu belirtilmiş bu değerden küçük olan dosyaları al
  sh "pngnq -f -e .png-nq #{file}"# optimize ediyor 
  out = "#{file}-nq" # out ile çıkış veriyor.
  if File.exist?(out)
    $?.success? ? File.rename(out, file) : File.delete(out)  # File.rename ile isim çakışması olursa bunu önlüyor.
  end
  png_comment(file, 'raked')  
end

def jpg_optim(file)  # burada ise jpg olan resimleri optimize ediyor. 
  sh "jpegoptim -q -m80 #{file}"  # jpegoptim ve alınan diğer argümanlar ile resmi optimize ediyor diğer satırda ise 
  sh "mogrify -comment 'raked' #{file}"  # son halini veriyor.
end		     



def optim
  pngs, jpgs = FileList["**/*.png"], FileList["**/*.jpg", "**/*.jpeg"] # png ve jpg, jpeg uzantılı resimleri sırasıyla pngs ve jpgs isimli iki       
 									#değişkene atıyor. 
  [pngs, jpgs].each do |a| 
    a.reject! { |f| %x{identify -format '%c' #{f}} =~ /[Rr]aked/ }  # optimize edilen resimleri çıkartıyor.
  end

  (pngs + jpgs).each do |f| #ayrı ayrı resimler için aşağıdaki işlemler yapılıyor
    w, h = %x{identify -format '%[fx:w] %[fx:h]' #{f}}.split.map { |e| e.to_i }  # burada resimlerin boyut düzenlemesi yapılıyor. 
										#resimler istenilen boyutta değilse yeniden düzenleniyor.
    if size > IMAGE_GEOMETRY[i] 						#yeniden optimize ediliyor. 
      arg = (i > 0 ? 'x' : '') + IMAGE_GEOMETRY[i].to_s 
      sh "mogrify -resize #{arg} #{f}"
    end
  end

   pngs.each { |f| png_optim(f) } #png resimler için
  jpgs.each { |f| jpg_optim(f) } #jpg resimler için
  (pngs + jpgs).each do |f| #her ikisi için ayrı ayrı 
    name = File.basename f                          # Optimize edilmiş resimler slayta gömülü ise tekrar üretiyor. Resme ilişik bir referans 
    FileList["*/*.md"].each do |src| 		    #olup olmadığına bak
      sh "grep -q '(.*#{name})' #{src} && touch #{src}" # dosyayı ekrana basmadan oluştur.
    end
  end
end
# Alt dizinlerde yapılandırma dosyasına mutlak dosya yoluyla erişiyoruz
default_conffile = File.expand_path(DEFAULT_CONFFILE)  #Config dosyası

FileList[File.join(PRESENTATION_DIR, "[^_.]*")].each do |dir| #Presentation_Dir ile karakterleri dir değişkenine atıp birleştir.Sonra Listeye at.
  next unless File.directory?(dir) # unless = if not eğer değilse 
  chdir dir do  
    name = File.basename(dir) #dosyayı listele ve name değişkeninin içine at
    conffile = File.exists?('presentation.cfg') ? 'presentation.cfg' : default_conffile #Config dosyasının işlemlerini yürüt.
    config = File.open(conffile, "r") do |f|
      PythonConfig::ConfigParser.new(f)
    end

    landslide = config['landslide']  #landslide için config
    if ! landslide   # Eğer landslide bölümü tanımlanmışsa 
      $stderr.puts "#{dir}: 'landslide' bölümü tanımlanmamış"  # ekrana hata bas
      exit 1 #çık
    end

    if landslide['destination']  #eğer landslide için destination kullanılmış ise 
      $stderr.puts "#{dir}: 'destination' ayarı kullanılmış; hedef dosya belirtilmeyin"  #ekrana hata bas
      exit 1  #çık 
    end

    if File.exists?('index.md')  # Eğer index.md dosyası var ise 
      base = 'index'  
      ispublic = true # dışarıya açıktır public
    elsif File.exists?('presentation.md') # eğer presentation.md dosyası var ise 
      base = 'presentation' 
      ispublic = false  #dışarıya kapalıdır.
    else #diğer durumlarda ise 
      $stderr.puts "#{dir}: sunum kaynağı 'presentation.md' veya 'index.md' olmalı"  # ekrana hata bas
      exit 1
    end

    basename = base + '.html'  # base değişkenine md uzantılı dosyaları atmıştık. Şimdi ise basename değişkeni açıp bu md dosalarına '.html' ekleriz
    thumbnail = File.to_herepath(base + '.png') # sayfanın png sini oluştur ve thumbnail e at
    target = File.to_herepath(basename)

    deps = []   #deps adında bir liste oluştur 
    (DEPEND_ALWAYS + landslide.values_at(*DEPEND_KEYS)).compact.each do |v| # Bu oluşturduğun listenin içersine at. 
      deps += v.split.select { |p| File.exists?(p) }.map { |p| File.to_filelist(p) }.flatten  # bağımlılık verilecek tüm dosyaları listele
    end
     # bağımlılık ağacının çalışması için tüm yolları bu dizine göreceli yap
    deps.map! { |e| File.to_herepath(e) }  # gerekli kontrolleri yap
    deps.delete(target)  #targeti sil 
    deps.delete(thumbnail) #thumbnail isimli değişkeni sil 

    tags = []  #tags adında bir liste oluştur ve buradaki etiketleri işle 

   presentation[dir] = {
      :basename  => basename,	# üreteceğimiz sunum dosyasının baz adı
      :conffile  => conffile,	# landslide konfigürasyonu (mutlak dosya yolu)
      :deps      => deps,	# sunum bağımlılıkları
      :directory => dir,	# sunum dizini (tepe dizine göreli)
      :name      => name,	# sunum ismi
      :public    => ispublic,	# sunum dışarı açık mı
      :tags      => tags,	# sunum etiketleri
      :target    => target,	# üreteceğimiz sunum dosyası (tepe dizine göreli)
      :thumbnail => thumbnail, 	# sunum için küçük resim
    }
  end
end

presentation.each do |k, v|  #sunum dosyaları için 
  v[:tags].each do |t| #etiketleme işlemini yap, Etiket için gereken bilgileri üret.
    tag[t] ||= []
    tag[t] << k
  end
end

tasktab = Hash[*TASKS.map { |k, v| [k, { :desc => v, :tasks => [] }] }.flatten] #Görev tablosu hazırlamak için görev sekmesi aç

presentation.each do |presentation, data| #Görevleri dinamik olarak üretmek için önce presentationun içerisine gir
  ns = namespace presentation do #isim uzayının içerisine gir.Her alt sunum dizin için bir alt görev tanımla 
    file data[:target] => data[:deps] do |t| #içeriği al 
      chdir presentation do   #sunumu hazırla 
        sh "landslide -i #{data[:conffile]}"   #her tarayıcı da düzgün çalışmasa da geçici bir çözümdür. 
        sh 'sed -i -e "s/^\([[:blank:]]*var hiddenContext = \)false\(;[[:blank:]]*$\)/\1true\2/" presentation.html'
        unless data[:basename] == 'presentation.html'
          mv 'presentation.html', data[:basename]  #ismi düzenle
        end
      end
    end

    file data[:thumbnail] => data[:target] do  #resmi alıp data[:target] hedefe gönder
      next unless data[:public] # eğer ki unless=if not bir sonraki public değil ise 
      sh "cutycapt " +
          "--url=file://#{File.absolute_path(data[:target])}#slide1 " +
          "--out=#{data[:thumbnail]} " +
          "--user-style-string='div.slides { width: 900px; overflow: hidden; }' " +  #düzenle
          "--min-width=1024 " +                        # küçük resmi 
          "--min-height=768 " +				#yeniden 
          "--delay=1000"				#boyutlandır ve 
      sh "mogrify -resize 240 #{data[:thumbnail]}"  
      png_optim(data[:thumbnail])			#optimize et
    end
 
    task :optim do	# optim görevi 
      chdir presentation do # dizini 
        optim		    #değiştir.
      end
    end

    task :index => data[:thumbnail]  #index görevini küçük resim üzerinde uygula 

    task :build => [:optim, data[:target], :index] #build görevini optim,target ve index için uygula

    task :view do  
      if File.exists?(data[:target])  #listelenen dosya olup olmadığına bak
        sh "touch #{data[:directory]}; #{browse_command data[:target]}"  # eğer varsa gereken dosyaları oluştur
      else
        $stderr.puts "#{data[:target]} bulunamadı; önce inşa edin" #yoksa ekrana hata mesajı bas
      end
    end

    task :run => [:build, :view]  #run görevi için build ve view i çalıştır.

    task :clean do # clean temizleme görevi 
      rm_f data[:target]  # sonradan oluşan artık dosyaları ve küçük resimleri temizle.
      rm_f data[:thumbnail]
    end

    task :default => :build #default görevini inşa et
  end

  ns.tasks.map(&:to_s).each do |t|  #alt görevleri görev tablosuna işle 
    _, _, name = t.partition(":").map(&:to_sym)  # görev sekmesine verilen görev işle
    next unless tasktab[name]
    tasktab[name][:tasks] << t
  end
end

namespace :p do  #isim uzayında 
  tasktab.each do |name, info| #görev sekmesi içindeki isim ve bilgilerle, yani görev tablosundan yararlanarak 
    desc info[:desc]  #ilgili görev isimlerini 
    task name => info[:tasks] # ve yeni bilgileri tanımla 
    task name[0] => name 
  end

  task :build do #build (oluştur) görevi 
    index = YAML.load_file(INDEX_FILE) || {}  #INDEX_FILE i yükle ve index değişkeninin içerisine at 
    presentations = presentation.values.select { |v| v[:public] }.map { |v| v[:directory] }.sort  # 'select' ile gereken sunum dosyasını seç
    unless index and presentations == index['presentations'] # ' if not ' eğer verilen değerler eşit değil ise
      index['presentations'] = presentations
      File.open(INDEX_FILE, 'w') do |f| #Dosyayı yazılabilir (write--> w ) olarak aç. 
        f.write(index.to_yaml)  # ve içerisine 'index.to_yaml yazıp arkasından 
        f.write("---\n") #sonuna '----\n ' ekle
      end
    end
  end

  desc "sunum menüsü" #sunum menüsünü azalarak sırala
  task :menu do # menü görevi
    lookup = Hash[ #çırpı tablosu 
      *presentation.sort_by do |k, v| #küçükten büyüğe (sort) sırala 
        File.mtime(v[:directory])
      end
      .reverse  #reverse = ters çevir 
      .map { |k, v| [v[:name], k] }
      .flatten
    ]
    name = choose do |menu| #menü ile seç bunu name değişkenine at
      menu.default = "1"  # default değerini 1 olarak tanımla 
      menu.prompt = color( #promp rengini tanımla 
        'Lütfen sunum seçin ', :headline   #başlık seçimi 
      ) + '[' + color("#{menu.default}", :special) + ']'  #renk seçimi 
      menu.choices(*lookup.keys) #seçim işlemi 
    end
    directory = lookup[name]  
    Rake::Task["#{directory}:run"].invoke #Görev : RAKE yani RAKE ET.
  end
  task :m => :menu  # m görev için menüyü çalıştır.
end

desc "sunum menüsü"  # azalarak sırala 
task :p => ["p:menu"] # p görevi --> menü
task :presentation => :p #presentation görevi --> p 
