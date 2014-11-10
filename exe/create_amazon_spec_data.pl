# create_amazon_spec_data.pl
# author:T.Aoki
# date:2011/6/3

#========== 改訂履歴 ==========
# date:2012/11/11 modify
# ・以下のファイルの商品番号5桁管理対応
#  -goods_spec.csv
#-----
# date:2012/11/23 modify
# ・goods.csvからのサイズ、カラーの出力に対応
#-----

########################################################
## Amazon店登録用のスペックデータを作成します。 
## 【入力ファイル】
## ・sabun_YYYYMMDD.csv
## ・goods.csv       
## ・goods_spec.csv
## 【参照ファイル】
## ・./XML/category.xml
## 【出力ファイル】
## ・amazon_spec_YYYYMMDD.csv
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Encode qw/ from_to /;
use Encode;
use XML::Simple;
use Data::Dumper;
use Text::ParseWords;
use Text::CSV_XS;

####################
##　ログファイル
####################
# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
	if (!mkdir $output_log_dir) {
		&output_log("ERROR!!($!) create $output_log_dir failed\n");
		exit 1;
	}
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."create_mall_entry_data"."$time_str".".log";
# ログファイルのオープン
if(!open(LOG_FILE, "> $log_file_name")) {
	&output_log("ERROR!!($!) $log_file_name open failed.\n");
	exit 1;
}

####################
##　入力ファイルの存在チェック
####################
#カレントディレクトリのオープン
my $current_dir=Cwd::getcwd();
my $input_dir="$current_dir"."/..";
opendir(INPUT_DIR, "$input_dir") or die("ERROR!! $input_dir open failed.");
#出力ファイル名
my $day = &to_YYYYMMDD_string(time());
my $output_spec_file_name="$input_dir"."/"."amazon_spec\_$day.csv";
#カレントディレクトリ内のファイル名をチェック
my $goods_file_name="goods.csv";
my $goods_spec_file_name="goods_spec.csv";
my $sabun_file_name="";
my $goods_file_find=0;
my $goods_spec_file_find=0;
my $sabun_file_find=0;
my $sabun_file_multi=0;
while (my $current_dir_file_name = readdir(INPUT_DIR)){
	if($current_dir_file_name eq $goods_file_name) {
		$goods_file_find=1;
		next;
	}
	if($current_dir_file_name eq $goods_spec_file_name) {
		$goods_spec_file_find=1;
		next;
	}
	elsif(index($current_dir_file_name, "sabun_", 0) == 0) {
		if ($sabun_file_find) {
			#sabun_YYYYMMDDファイルが複数存在する
			$sabun_file_multi=1;
			next;
		}
		else {
			$sabun_file_find=1;
			$sabun_file_name=$current_dir_file_name;
		}
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルがカレントディレクトリに存在しない
	print("ERROR!! Not exist $goods_file_name.\n");
	print LOG_FILE "ERROR!! Not exist $goods_file_name.\n";
}
if (!$goods_spec_file_find) {
	#goods_spec.csvファイルがカレントディレクトリに存在しない
	print("ERROR!! Not exist $goods_spec_file_name.\n");
	print LOG_FILE "ERROR!! Not exist $goods_spec_file_name.\n";
}
if (!$sabun_file_find) {
	#sabun_YYYYMMDD.csvファイルがカレントディレクトリに存在しない
	print LOG_FILE "ERROR!! Not exist sabun_YYYYMMDD.csv.\n"
}
if ($sabun_file_multi) {
	#sabun_YYYYMMDD.csvファイルがカレントディレクトリに複数存在する
	print LOG_FILE "ERROR!! sabun_YYYYMMDD.csv is exist over 2.\n";
}

if (!$goods_file_find || !$goods_spec_file_find || !$sabun_file_find || $sabun_file_multi) {
	close(LOG_FILE);
	exit 1;
}

####################
##　参照ファイルの存在チェック
####################
my $goods_spec_xml_filename="goods_spec.xml";
my $category_xml_filename="category.xml";
#参照ファイル配置ディレクトリのオープン
my $ref_dir ="$current_dir"."/xml";
if (!opendir(REF_DIR, "$ref_dir")) {
	&output_log("ERROR!!($!) $ref_dir open failed.");
	exit 1;
}
#　参照ファイルの有無チェック
my $goods_spec_xml_file_find=0;
my $category_xml_file_find=0;
while (my $ref_dir_file_name = readdir(REF_DIR)){
	if($ref_dir_file_name eq $goods_spec_xml_filename) {
		$goods_spec_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $category_xml_filename) {
		$category_xml_file_find=1;
		next;
	}
}
closedir(REF_DIR);
if (!$goods_spec_xml_file_find) {
	#goods_spec.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $goods_spec_xml_filename.\n");
}
if (!$category_xml_file_find) {
	#category.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $category_xml_filename.\n");
}
if (!$goods_spec_xml_file_find || !$category_xml_file_find) {
	exit 1;
}
$goods_spec_xml_filename="$ref_dir"."/"."$goods_spec_xml_filename";
$category_xml_filename="$ref_dir"."/"."$category_xml_filename";

# ====================

# 入力ファイルのオープン
$sabun_file_name="$input_dir"."/"."$sabun_file_name";
my $input_sabun_csv = Text::CSV_XS->new({ binary => 1 });
my $input_sabun_file_disc;
if (!open $input_sabun_file_disc, "<", $sabun_file_name) {
	output_log("ERROR!!($!) $sabun_file_name open failed.");
	exit 1;
}
$goods_file_name="$input_dir"."/"."$goods_file_name";
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_file_disc;
if (!open $input_goods_file_disc, "<", $goods_file_name) {
	output_log("ERROR!!($!) $goods_file_name open failed.");
	exit 1;
}
$goods_spec_file_name="$input_dir"."/"."$goods_spec_file_name";
my $input_spec_csv = Text::CSV_XS->new({ binary => 1 });
my $input_spec_file_disc;
if (!open $input_spec_file_disc, "<", $goods_spec_file_name) {
	output_log("ERROR!!($!) $goods_spec_file_name open failed.");
	exit 1;
}
# 出力CSV用ファイル
my $output_spec_csv = Text::CSV_XS->new({ binary => 1 });
open(OUTPUT_SPEC_FILE, "> $output_spec_file_name") or die("ERROR!! $output_spec_file_name open failed.");

## スペック情報のソート順を保持
our @globel_spec_sort=&get_spec_sort_from_xml();

# 差分ファイルを読みだす(1行読み飛ばす)
my $max_spec_count=0;
my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	# goods_specファイルの読み出し
	my $spec_num=0;
	seek $input_spec_file_disc,0,0;
	my $goods_spec_line = $input_spec_csv->getline($input_spec_file_disc);
	while($goods_spec_line = $input_spec_csv->getline($input_spec_file_disc)){	
		my $sabun_code_5=substr(@$sabun_line[0], 0, 5);
		# スペックを出力する(カラー、ギフトは対象外)
		if (($sabun_code_5==@$goods_spec_line[0])&&(@$goods_spec_line[1] != 7)&&(@$goods_spec_line[1] != 8)) {
			$spec_num++;
		}
	}
	seek $input_goods_file_disc,0,0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){	
		# 商品コードが合致したらサイズがあるかどうかを保持する
		if ((@$sabun_line[0] eq @$goods_line[0]) && (@$goods_line[5]ne"")) {
			$spec_num++;
			last;
		}
	}
	if ($max_spec_count < $spec_num) {
		#書き込むスペック情報の最大数を保持
		$max_spec_count=$spec_num;
	}
}

# CSVの項目名を出力する
my $csv_item_name1="商品コード";
Encode::from_to( $csv_item_name1, 'utf8', 'shiftjis' );
my $csv_item_name2="仕様名";
Encode::from_to( $csv_item_name2, 'utf8', 'shiftjis' );
my $csv_item_name3="内容";
Encode::from_to( $csv_item_name3, 'utf8', 'shiftjis' );
for (my $i=0; $i<$max_spec_count; $i++) {
	$output_spec_csv->combine($csv_item_name1) or die $output_spec_csv->error_diag();
	print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
	$output_spec_csv->combine($csv_item_name2) or die $output_spec_csv->error_diag();
	print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
	$output_spec_csv->combine($csv_item_name3) or die $output_spec_csv->error_diag();
	my $post_fix_str="";
	if (($i+1) == $max_spec_count) {
		$post_fix_str="\n";
	}
	else {
		$post_fix_str=",";
	}
	print OUTPUT_SPEC_FILE $output_spec_csv->string(), $post_fix_str;
}

my $is_first=1;
# 差分ファイルを読みだす(1行読み飛ばす)
seek $input_sabun_file_disc,0,0;
$sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	# 登録する商品コード読み出し
	my $entry_goods_code=@$sabun_line[0];
	# サイズをgoods.csvから読みだす
	my $size_info="";
	my $find_goods_flag=0;
	seek $input_goods_file_disc,0,0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){	
		# 登録情報から商品コード読み出し
		my $goods_code=@$goods_line[0];
		# 商品コードが合致したらコードを保持する
		if ($entry_goods_code eq $goods_code) {
			$size_info = @$goods_line[5];
			$find_goods_flag=1;
			last;
		}
	}
	# sabunにあってgoodsに無い商品の場合はskip
	if (!$find_goods_flag) {
		next;
	}
	my $sabun_code_5=substr($entry_goods_code, 0, 5);
	# goods_specファイルの読み出し
	seek $input_spec_file_disc,0,0;
	my $goods_spec_line = $input_spec_csv->getline($input_spec_file_disc);
	my @entry_goods_specs;
	while($goods_spec_line = $input_spec_csv->getline($input_spec_file_disc)){	
		# スペックを出力する(カラー、ギフトは対象外)
		if (($sabun_code_5==@$goods_spec_line[0])&&(@$goods_spec_line[1] != 7)&&(@$goods_spec_line[1] != 8)) {
			push(@entry_goods_specs, @$goods_spec_line[1]);
			push(@entry_goods_specs, @$goods_spec_line[2]);
		}
	}
	# 商品スペックをソート
	my @specs;
	my $spec_count = @entry_goods_specs;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			if ($entry_goods_specs[$i] ne $spec_sort_num) {
				next;
			}
			push(@specs, &get_spec_info_from_xml($entry_goods_specs[$i]));
			push(@specs, $entry_goods_specs[$i+1]);
			last;
		}
	}
	# サイズを出力
	my $size_str="サイズ";
	Encode::from_to( $size_str, 'utf8', 'shiftjis' );	
	if ($size_info ne "") {
		$output_spec_csv->combine($entry_goods_code) or die $output_spec_csv->error_diag();
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
		$output_spec_csv->combine($size_str) or die $output_spec_csv->error_diag();
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
		$output_spec_csv->combine($size_info) or die $output_spec_csv->error_diag();	
		my $str_prefix="";
		if ($spec_count > 0) {
			$str_prefix=",";
		}
		else {
			$str_prefix="\n";
		}
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), $str_prefix;	
	}
	# 商品スペックを出力する
	for (my $i=0; $i < $spec_count; $i+=2) {
		$output_spec_csv->combine($entry_goods_code) or die $output_spec_csv->error_diag();
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
		$output_spec_csv->combine($specs[$i]) or die $output_spec_csv->error_diag();
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), ",";
		$output_spec_csv->combine($specs[$i+1]) or die $output_spec_csv->error_diag();
		my $str_prefix="";
		if ($i+2 == $spec_count) {
			$str_prefix="\n";
		}
		else {
			$str_prefix=",";
		}
		print OUTPUT_SPEC_FILE $output_spec_csv->string(), $str_prefix;
	}
}

close $input_goods_file_disc;
close $input_spec_file_disc;
close $input_sabun_file_disc;
close(LOG_FILE);

# ==============================

## スペック情報のソート順を取得する
sub get_spec_sort_from_xml {
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$goods_spec_xml_filename",ForceArray=>['spec']);
	# XMLからカテゴリを取得し、ハッシュに一時的に保持する
	my $count=0;
	my $info="";
	my %temp_spec_sort;
	while(1) {
		my $xml_spec_sort_num = $xml_data->{spec}[$count]->{spec_sort_num};
		my $xml_spec_number = $xml_data->{spec}[$count]->{spec_number};
		if (!$xml_spec_sort_num) {
			# 情報を取得できなかったら終了
			last;
		}
		$temp_spec_sort{$xml_spec_sort_num}=$xml_spec_number;
		$count++;
	}	
	# スペック情報のソート順を配列変数に格納する
	my @spec_sort;
	foreach my $key ( sort { $a <=> $b } keys %temp_spec_sort ) { 
		push(@spec_sort, $temp_spec_sort{$key});
	}
	return @spec_sort;
}

## 指定されたスペック番号に対応するスペック名をXMLファイルから取得する
sub get_spec_info_from_xml {
	my $spec_number = $_[0]; 
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$goods_spec_xml_filename",ForceArray=>['spec']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_spec_number = $xml_data->{spec}[$count]->{spec_number};
		Encode::_utf8_off($xml_spec_number);
		Encode::from_to( $xml_spec_number, 'utf8', 'shiftjis' );
		$info = $xml_data->{spec}[$count]->{spec_name};
		if (!$info) {
			# 情報を取得できなかったので、終了
			output_log("not exist spec_number($spec_number) in $goods_spec_xml_filename\n");
			last;
		}
		Encode::_utf8_off($info);
		Encode::from_to( $info, 'utf8', 'shiftjis' );
		if ($spec_number == $xml_spec_number){
			last;
		}
		$count++;
	}
	return $info;
}

## 指定されたGLOBERのカテゴリ番号に対応するYahooのカテゴリ名をXMLファイルから取得する
sub get_category_from_xml {
	my $category_number = $_[0]; 
	#category.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin('./xml/category.xml',ForceArray=>['category']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info=0;
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_number = $xml_data->{category}[$count]->{g_category_num};
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number eq $xml_category_number){
			$info = $xml_data->{category}[$count]->{g_category_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	return $info;
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
  return $result;
}
