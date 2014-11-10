# get_image.pl
# author:T.Aoki
# date:2011/5/10
#========== 改訂履歴 ==========
# date:2012/11/1 modify
# ・goods.csvの9桁化に対応
#-----
# date:2012/11/23 modify
# 9枚以上の画像に対応
# ファイル名に"_a","_b","_c"を付与
#-----

########################################################
## 指定された商品コードの画像ファイルをGlober(本店)から取得する。 
## 【入力ファイル】
## ・goods.csv
## ・sabun_YYYYMMDD.csv
## 【出力ファイル】
## ・image_num.csv
##    -取得した画像数を記載
## 【ログファイル】
## ・get_image_yyyymmddhhmmss.log
##    -エラー情報などの処理内容を出力
##
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Image::Magick;
use File::Copy;
use File::Path;
use Archive::Zip;
use lib './lib'; 
use ImgResize;
use IO::Handle;
use Text::CSV_XS;

# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
    mkdir $output_log_dir or die "ERROR!! create $output_log_dir failed";
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."get_image"."$time_str".".log";
# ログファイルのオープン
if(!open(LOG_FILE, "> $log_file_name")) {
	print "ERROR!!($!) $log_file_name open failed.\n";
	exit 1;
}
# グローバー画像URL
my $glober_url="http://glober.jp/img/mall";
# 出力ファイルを格納するフォルダ名
my $output_dir="./..";
# 各商品のSKU番号と画像数を格納するファイル名
my $image_num_file_name="$output_dir"."/"."image_num.csv";
# 画像を保存するフォルダ名
my $r_image_dir="./../rakuten_up_data/rakuten_image";
my $y_image_dir="./../yahoo_up_data/yahoo_image";
my $y_s_over6_image_dir="./../yahoo_up_data/yahoo_image_s_over6";
# 取得する写真上限枚数(モール店で使用する最大画像数)
my $get_image_max_num_= 50;
# Yahooの画像ZIPファイルに格納するファイル数(上限15MB)
my $y_image_max=140;
my $y_s_over6_image_max=280;
# 画像変換用モジュールの初期化
my $img_resize = new ImgResize(-1);
# ZIP用モジュール
my $y_zip = Archive::Zip->new();
my $y_s_over6_zip = Archive::Zip->new();
# 入力ファイル格納フォルダのオープン
my $input_dir=Cwd::getcwd();
$input_dir="$input_dir"."/..";
opendir(INPUT_DIR, "$input_dir") or die("ERROR!! $input_dir failed.");
#　入力ファイル格納フォルダ内のファイル名をチェック
my $goods_file_name="goods.csv";
my $goods_file_find=0;
my $sabun_file_name="";
my $sabun_file_find=0;
my $sabun_file_multi=0;
my $input_dir_file_name;
while ($input_dir_file_name = readdir(INPUT_DIR)){
	if($input_dir_file_name eq $goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif(index($input_dir_file_name, "sabun_", 0) == 0) {
		if ($sabun_file_find) {
			#sabun_YYYYMMDDファイルが複数存在する
			$sabun_file_multi=1;
			next;
		}
		else {
			$sabun_file_find=1;
			$sabun_file_name=$input_dir_file_name;
			next;
		}
	}
}
closedir(INPUT_DIR);
if (!$sabun_file_find) {
	#sabun_YYYYMMDD.csvファイルが存在しない
	&output_log("ERROR!! Not exist sabun_YYYYMMDD.csv.\n");
}
if ($sabun_file_multi) {
	#sabun_YYYYMMDD.csvファイルが複数存在する
	&output_log("ERROR!! sabun_YYYYMMDD.csv is exist over 2.\n");
}
if (!$goods_file_find || !$sabun_file_find || $sabun_file_multi) {
	#入力ファイルが不正
	exit 1;
}

# 入力ファイルにディレクトリを付加
$goods_file_name = "$input_dir"."/"."$goods_file_name";
$sabun_file_name = "$input_dir"."/"."$sabun_file_name";
# 入力ファイルのオープン
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_sabun_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_file_disc;
if (!open $input_goods_file_disc, "<", $goods_file_name) {
	&output_log("ERROR!!($!) $goods_file_name open failed.");
	exit 1;
}
my $input_sabun_file_disc;
if (!open $input_sabun_file_disc, "<", $sabun_file_name) {
	&output_log("ERROR!!($!) $sabun_file_name open failed.");
	exit 1;
}
# 出力ファイルのオープン
my $output_image_num_csv = Text::CSV_XS->new({ binary => 1 });
my $output_image_num_file_disc;
if (!open $output_image_num_file_disc, ">", $image_num_file_name) {
	&output_log("ERROR!!($!) $image_num_file_name open failed.");
	exit 1;
}	

# 画像を保存するフォルダを作成
if(-d $r_image_dir) {
	# 既に存在している場合は削除
	rmtree($r_image_dir, {verbose => 1});
}
mkpath($r_image_dir) or die("ERROR!! $r_image_dir create failed.");
if(-d $y_image_dir) {
	# 既に存在している場合は削除
	rmtree($y_image_dir, {verbose => 1});
}
mkpath($y_image_dir) or die("ERROR!! $y_image_dir create failed.");
if(-d $y_s_over6_image_dir) {
	# 既に存在している場合は削除
	rmtree($y_s_over6_image_dir, {verbose => 1});
}
mkpath($y_s_over6_image_dir) or die("ERROR!! $y_s_over6_image_dir create failed.");

# ヤフー用zipファイルに格納するファイル数
my $y_zip_count=0;
my $y_s_over6_zip_count=0;

# 処理開始
&output_log("**********START**********\n");

# SKUか通常商品かの判定を行い商品コードリストを作成
my @goods_code_list;
my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)) {
	# 登録する商品コード読み出し
	my $entry_goods_code_tmp=@$sabun_line[0];
	chomp($entry_goods_code_tmp);
	# 商品コードの上位7桁を切り出し
	my $entry_goods_7code=substr($entry_goods_code_tmp, 0, 7);
	my $comp_count=0;
	my $find_sku=0;
	# goodsファイルの読み出し(項目行1行読み飛ばし)
	seek $input_goods_file_disc,0,0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){
		my $comp_code_tmp=@$goods_line[0];
		# 商品コードの上位7桁を切り出し
		my $comp_code=substr($comp_code_tmp, 0, 7);
		if ($entry_goods_7code eq $comp_code) {
			if (++$comp_count > 1) {
				$find_sku=1;
				last;
			}
		}
	}
	# SKUの場合は7桁を登録
	my $entry_code="";
	if ($find_sku) {
		$entry_code=$entry_goods_7code;
	}
	else {
		$entry_code=$entry_goods_code_tmp;	
	}
	# 既に登録済みでないかチェック
	my $find_flag=0;
	foreach my $check_code ( @goods_code_list ) {
		if ($check_code eq $entry_code) {
			$find_flag=1;
			last;
		}
	}
	if ($find_flag) {
		next;
	}
	else {
		push(@goods_code_list, $entry_code);
	}
}
# wgetで商品画像を取得する
foreach my $get_image_code ( @goods_code_list ) {
	my $rtn=0;
	my $cnt=0;
	my $correct_image_code="";
	if (length($get_image_code) == 9) {
		# 画像取得の為に7桁にする
		$correct_image_code=substr($get_image_code, 0, 7);
	}
	else {
		$correct_image_code=$get_image_code;
	}

	while(!$rtn) {
		$cnt++;
		if ($cnt > $get_image_max_num_) {
			last;
		}
		# 楽天用フォルダに画像を取得
		my $image_file_name="$correct_image_code"."_$cnt".".jpg";
		$rtn = system("wget.exe -q -P $r_image_dir $glober_url/$cnt/$image_file_name");
		if($rtn){
			last;
		}
		if (length($get_image_code) != 7) {
			#SKUじゃなかった場合は画像ファイル名をリネーム
			rename("$r_image_dir/$correct_image_code\_$cnt.jpg", "$r_image_dir/$get_image_code\_$cnt.jpg");
		}
		if ($cnt != 1) {
			# 1の画像以外はサムネイルを生成
			&image_resize("$r_image_dir/$get_image_code\_$cnt.jpg", "$r_image_dir/$get_image_code\_$cnt"."s.jpg", 196, 196, 70);
		}
		
		# 9以上の画像はファイル名を変更する
		my $correct_image_name = "";
		my $correct_thumbnail_image_name = "";
		my $correct_cnt=0;
		if ($cnt < 9) {
			$correct_image_name = "$cnt.jpg";
			$correct_thumbnail_image_name = "$cnt"."s.jpg";
		}			
		elsif ($cnt >= 9 && $cnt <= 16) {
			$correct_cnt=$cnt%8;
			$correct_image_name = "a\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "a\_$correct_cnt"."s.jpg";	
		}
		elsif ($cnt >= 17 && $cnt <= 24) {
			$correct_cnt=$cnt%8;
			$correct_image_name = "b\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "b\_$correct_cnt"."s.jpg";
		}
		elsif ($cnt >= 25 && $cnt <= 32) {
			$correct_cnt=$cnt%8;
			$correct_image_name = "c\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "c\_$correct_cnt"."s.jpg";
		}
		rename("$r_image_dir/$get_image_code\_$cnt.jpg", "$r_image_dir/$get_image_code\_$correct_image_name");			
		rename("$r_image_dir/$get_image_code\_$cnt"."s.jpg", "$r_image_dir/$get_image_code\_$correct_thumbnail_image_name");	
		# Yahoo用フォルダに画像をコピー
		if ($cnt==1) {
			copy( "$r_image_dir/$get_image_code\_$cnt.jpg", "$y_image_dir/$get_image_code.jpg" ) or die("ERROR!! $y_image_dir/$get_image_code.jpg copy failed.");
			&image_resize("$y_image_dir/$get_image_code.jpg", "$y_image_dir/$get_image_code.jpg", 600, 600, 0);
			# ZIPファイル化
			&add_y_zip("$y_image_dir/$get_image_code.jpg", "$get_image_code.jpg");
		}
		else {
			if ($cnt>= 6) {
				copy( "$r_image_dir/$get_image_code\_$correct_image_name", "$y_s_over6_image_dir/$get_image_code\_$correct_image_name" ) or die("ERROR!! $y_s_over6_image_dir/$get_image_code\_$cnt.jpg copy failed.");					
				&image_resize("$y_s_over6_image_dir/$get_image_code\_$correct_image_name", "$y_s_over6_image_dir/$get_image_code\_$correct_image_name", 600, 600, 0);
				# ZIPファイル化
				&add_y_s_over6_zip("$y_s_over6_image_dir/$get_image_code\_$correct_image_name", "$get_image_code\_$correct_image_name");
			}
			else {
				# Yahoo用画像フォルダにコピー
				copy( "$r_image_dir/$get_image_code\_$correct_image_name", "$y_image_dir/$get_image_code\_$correct_image_name" ) or die("ERROR!! $y_image_dir/$get_image_code\_$correct_image_name copy failed.");
				&image_resize("$y_image_dir/$get_image_code\_$correct_image_name", "$y_image_dir/$get_image_code\_$correct_image_name", 600, 600, 0);
				&add_y_zip("$y_image_dir/$get_image_code\_$correct_image_name", "$get_image_code\_$correct_image_name");
			}
			copy( "$r_image_dir/$get_image_code\_$correct_thumbnail_image_name", "$y_s_over6_image_dir/$get_image_code\_$correct_thumbnail_image_name" ) or die("ERROR!! $y_s_over6_image_dir/$get_image_code\_$correct_thumbnail_image_name"."s.jpg copy failed.");
			&add_y_s_over6_zip("$y_s_over6_image_dir/$get_image_code\_$correct_thumbnail_image_name", "$get_image_code\_$correct_thumbnail_image_name");
		}
	}
	# 画像数をファイルに書き込み
	$cnt--;
	$output_image_num_csv->combine($get_image_code) or die $output_image_num_csv->error_diag();
	print $output_image_num_file_disc $output_image_num_csv->string(), ",";
	$output_image_num_csv->combine($cnt) or die $output_image_num_csv->error_diag();
	print $output_image_num_file_disc $output_image_num_csv->string(), "\n";
}

# ZIPファイルのクローズ
&terminate_y_zip("$y_image_dir/y_pic_$y_zip_count.zip");
&terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");

# 処理終了
&output_log("Process is Success!!\n");
&output_log("**********END**********\n");

# CSVモジュールの終了処理
$input_goods_csv->eof;
$input_sabun_csv->eof;
$output_image_num_csv->eof;
# ファイルのクローズ
close $input_goods_file_disc;
close $input_sabun_file_disc;
close $output_image_num_file_disc;
close(LOG_FILE);

##########################################################################################
##############################  sub routin   #############################################
##########################################################################################

## 画像をリサイズする
sub image_resize() {
	( $img_resize->{in} , $img_resize->{out} , $img_resize->{width},  $img_resize->{height}, $img_resize->{quality}) = @_ ;
	# リサイズ条件の設定
	$img_resize->{ext}      = '.jpg';
	$img_resize->{exif_cut} =   1;
	$img_resize->{jpeg_prog} = 'convert -geometry %wx%h -quality %q -sharpen 10 %i %o';
	$img_resize->{png_prog}  = $img_resize->{jpeg_prog};
	$img_resize->{gif_prog}  = $img_resize->{jpeg_prog};
	# リサイズ
	$img_resize->resize;
}

## Yahoo用のZIPファイルに画像をファイルを追加
sub add_y_zip() {
	$y_zip->addFile("$_[0]", "$_[1]");
	if (!(++$y_zip_count % $y_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_zip("$y_image_dir/y_pic_$y_zip_count.zip");
		$y_zip = Archive::Zip->new();
	}
}		

## Yahoo用のZIPファイルにthumbnail, 6以上の画像を追加
sub add_y_s_over6_zip() {
	$y_s_over6_zip->addFile("$_[0]", "$_[1]");
	if (!(++$y_s_over6_zip_count % $y_s_over6_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");
		$y_s_over6_zip = Archive::Zip->new();
	}
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_zip() {
	$y_zip->writeToFileNamed("$_[0]");
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_s_over6_zip() {
	$y_s_over6_zip->writeToFileNamed("$_[0]");
}

## ログ出力
sub output_log() {
	my $day=::to_YYYYMMDD_string();
	my $old_fh = select(LOG_FILE);
	my $old_dolcol = $|;
	$| = 1;
	print"[$day]:$_[0]";
	$| = $old_dolcol;
	select($old_fh);
	print"[$day]:$_[0]";
}

## 現在日時取得関数
sub to_YYYYMMDD_string() {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}
