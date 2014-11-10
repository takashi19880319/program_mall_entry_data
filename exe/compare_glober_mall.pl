# compare_glober_mall.pl
# author:T.Aoki
# date:2011/5/6

#========== 改訂履歴 ==========
# date:2012/11/11 modify
# ・genre_goods.csvの読み込み処理削除
#  -特にどこでも使用されていない為sabunファイルへの出力中止
#-----

########################################################
## Glober(本店)とHFF(楽天店)の商品の差分を抽出するプログラム  
## です。抽出には以下のファイルを入力として使用します。
## 【入力ファイル】
## ・goods.csv                                         
##    -本店の管理をしているECBeingからダウンロードしたアイテムリストファイル                        
## ・dl-itemYYYYMMDDHHMM-X.csv
## ・dl-selectYYYYMMDDHHMM-X.csv
##    -楽天管理システムからダウンロードしたファイル
## ・cut_goods_code.csv
##    -差分ファイルから除外する商品コード一覧
## 【出力ファイル】
## ・sabun_YYYYMMDD.csv
##   -本店とモール店の差分商品
##  　　 -商品番号
##   　　-商品ブランド
##   　　-商品名
##   　　-在庫数
## ・size_addtion_YYYYMMDD.csv
##   -サイズ追加商品
##     -商品番号
##     -商品ブランド
##     -商品名
##     -在庫数
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use XML::Simple;
use Encode;
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
my $log_file_name="$output_log_dir"."/"."compare_glober_mall"."$time_str".".log";
# ログファイルのオープン
open(LOG_FILE, "> $log_file_name") or die("ERROR!! $log_file_name open failed.");
# 出力ファイルを格納するフォルダ名
my $output_dir="./..";
# 出力ファイル名
my $date_str = sprintf("%04d%02d%02d" ,$year + 1900, $mon + 1, $mday);
my $sabun_file_name="$output_dir"."/"."sabun_"."$date_str".".csv";
my $size_addition_file_name="$output_dir"."/"."size_addtion_"."$date_str".".csv";
# 入力ファイル格納フォルダのオープン
my $input_dir=Cwd::getcwd();
$input_dir="$input_dir"."/..";
opendir(INPUT_DIR, "$input_dir") or die("ERROR!! $input_dir failed.");
#　入力ファイル格納フォルダ内のファイル名をチェック
my $category_xml_filename="./xml/category.xml";

my $goods_file_name="goods.csv";
my $goods_file_find=0;
my $dl_item_file_name="";
my $dl_item_file_find=0;
my $dl_item_file_multi=0;
my $dl_select_file_name="";
my $dl_select_file_find=0;
my $dl_select_file_multi=0;
my $cut_goods_code_file_name="cut_goods_code.csv";
my $input_dir_file_name;
while ($input_dir_file_name = readdir(INPUT_DIR)){
	if($input_dir_file_name eq $goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif(index($input_dir_file_name, "dl-item", 0) != -1) {
		if ($dl_item_file_find) {
			#dl-itemYYYYMMDDファイルが複数存在する
			$dl_item_file_multi=1;
			next;
		}
		else {
			$dl_item_file_find=1;
			$dl_item_file_name=$input_dir_file_name;
			next;
		}
	}
	elsif(index($input_dir_file_name, "dl-select", 0) != -1) {
		if ($dl_select_file_find) {
			#dl-itemYYYYMMDDファイルが複数存在する
			$dl_select_file_multi=1;
			next;
		}
		else {
			$dl_select_file_find=1;
			$dl_select_file_name=$input_dir_file_name;
			next;
		}
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルが存在しない
	output_log("ERROR!! Not exist $goods_file_name.\n");
}
if (!$dl_item_file_find) {
	#dl-itemyyyymmdd.csvファイルが存在しない
	print("ERROR!! Not exist dl-itemyyyymmdd.csv.\n");
}
if ($dl_item_file_multi) {
	#dl-itemyyyymmdd.csvファイルが複数存在する
	output_log("ERROR!! dl-itemyyyymmdd.csv　is exist over 2.\n");
}
if (!$dl_select_file_find) {
	#dl-selectyyyymmdd.csvファイルが存在しない
	print("ERROR!! Not exist dl-selectyyyymmdd.csv.\n");
}
if ($dl_select_file_multi) {
	#dl-selectyyyymmdd.csvファイルが複数存在する
	output_log("ERROR!! dl-selectyyyymmdd.csv　is exist over 2.\n");
}
if (!$goods_file_find || !$dl_item_file_find || $dl_item_file_multi || !$dl_select_file_find || $dl_select_file_multi) {
	#入力ファイルが不正
	exit 1;
}

# 入力ファイルのオープン
$goods_file_name = "$input_dir"."/"."$goods_file_name";
if (!open(GOODS_FILE, "< $goods_file_name")) {
	output_log("ERROR!!($!) $goods_file_name open failed.\n");
	exit 1;
}

my $is_exist_cut_goods_code_file=0;
$cut_goods_code_file_name = "$input_dir"."/"."$cut_goods_code_file_name";
if(-e $cut_goods_code_file_name) {
	#ファイルが存在すれば読み込む
	if (!open(CUT_GOODS_CODE_FILE, "< $cut_goods_code_file_name")) {
		output_log("ERROR!!($!) $cut_goods_code_file_name open failed.\n");
		exit 1;
	}
	$is_exist_cut_goods_code_file=1;
}
$dl_item_file_name = "$input_dir"."/"."$dl_item_file_name";
if (!open(ITEM_FILE, "< $dl_item_file_name")) {
	output_log("ERROR!!($!) $dl_item_file_name open failed.\n");
	exit 1;
}
$dl_select_file_name = "$input_dir"."/"."$dl_select_file_name";
if (!open(SELECT_FILE, "< $dl_select_file_name")) {
	output_log("ERROR!!($!) $dl_select_file_name open failed.\n");
	exit 1;
}
# 出力ファイルのオープン
my $output_sabun_csv = Text::CSV_XS->new({ binary => 1 });
if (!open(SABUN_FILE, "> $sabun_file_name")) {
	output_log("ERROR!!($!) $sabun_file_name open failed.");
	exit 1;
}
my $output_size_csv = Text::CSV_XS->new({ binary => 1 });
if (!open(SIZE_ADDITION_FILE, "> $size_addition_file_name")) {
	output_log("ERROR!!($!) $size_addition_file_name open failed.");
	exit 1;
}
# 処理開始
output_log("**********START**********\n");

# CSV項目の出力
my @csv_item_name=("商品コード","カテゴリ名","商品名","販売価格","サイズ","カラー","在庫数");
my $csv_item_name_num=@csv_item_name;
my $csv_item_name_count=0;
for my $csv_item_name_str (@csv_item_name) {
	Encode::from_to( $csv_item_name_str, 'utf8', 'shiftjis' );
	$output_sabun_csv->combine($csv_item_name_str) or die $output_sabun_csv->error_diag();
	my $post_fix_str="";
	if (++$csv_item_name_count >= $csv_item_name_num) {
		$post_fix_str="\n";
	}
	else {
		$post_fix_str=",";
	}
	print SABUN_FILE $output_sabun_csv->string(), $post_fix_str;
}
$csv_item_name_count=0;
for my $csv_item_name_str (@csv_item_name) {
	$output_size_csv->combine($csv_item_name_str) or die $output_size_csv->error_diag();
	my $post_fix_str="";
	if (++$csv_item_name_count >= $csv_item_name_num) {
		$post_fix_str="\n";
	}
	else {
		$post_fix_str=",";
	}
	print SIZE_ADDITION_FILE $output_size_csv->string(), $post_fix_str;
}

# 1行目は読み飛ばす
my $goods_line = <GOODS_FILE>;
while($goods_line = <GOODS_FILE>){
	# 本店の商品コード抽出
	my @glober_goods_code=split(/,/, $goods_line);
	my $glober_goods_code=$glober_goods_code[0];
	# itemファイルの読み出し
	seek(ITEM_FILE,0,0);
	# 1行目は読み飛ばす
	my $item_line = <ITEM_FILE>;
	my $find_flag=0;
	while($item_line = <ITEM_FILE>){	
		# itemファイルの9桁コードと比較
		my @rakuten_item_code=split(/,/, $item_line);
		my $rakuten_item_code=$rakuten_item_code[2];
		my $index_num=index($rakuten_item_code, "\"",1);
		my $code=substr($rakuten_item_code, 1, $index_num-1);
		if (length($code) == 9 && $code==$glober_goods_code) {
			#9桁で合致した場合はflagを立てる
			$find_flag=1;
			last;
		}
	}
	my $already_entry_num=0;
	if($find_flag != 1) {
		# selectファイルの読み出し
		# 1行目は読み飛ばす	
		seek(SELECT_FILE,0,0);
		my $select_line = <SELECT_FILE>;
		while($select_line = <SELECT_FILE>){	
			# selectファイルの7桁+2桁コードと比較
			my @rakuten_select_code=split(/,/, $select_line);
			my $rakuten_select_7_code=$rakuten_select_code[1];
			my $rakuten_select_2_code=$rakuten_select_code[6];
			my $rakuten_select_7_code_index=index($rakuten_select_7_code, "\"",1);
			my $code_7=substr($rakuten_select_7_code, 1, $rakuten_select_7_code_index-1);
			my $rakuten_select_2_code_index=index($rakuten_select_2_code, "\"",1);
			my $code_2=substr($rakuten_select_2_code, 1, $rakuten_select_2_code_index-1);
			my $code="$code_7$code_2";
			if ($code==$glober_goods_code) {
				#7桁+2桁で合致した場合はflagを立てる
				$find_flag=1;
				last;
			}
			# 商品コードの上位7桁を切り出し
			my $glober_goods_code_index=index($glober_goods_code, "\"",7);
			my $glober_goods_code_7=substr($glober_goods_code, 0, $glober_goods_code_index-1);
			if ($code_7==$glober_goods_code_7) {
				#7桁で合致するものがある場合はカウントアップ
				$already_entry_num++;
			}
		}
	}
	if($find_flag != 1) {
		if ($is_exist_cut_goods_code_file) {
			# 除外ファイルの読み出し
			seek(CUT_GOODS_CODE_FILE,0,0);
			while(my $cut_goods_code_line = <CUT_GOODS_CODE_FILE>){	
				# 除外ファイルと比較
				my @rakuten_cut_code=split(/,/, $cut_goods_code_line);
				my $rakuten_cut_code=$rakuten_cut_code[0];
				if ($rakuten_cut_code==$glober_goods_code) {
					#除外リストに合致した場合はflagを立てる
					$find_flag=1;
					last;
				}
			}
		}
	}

	# item/selectどちらにもなく、除外リストにもないもの
	if($find_flag != 1){
		if ($already_entry_num) {
			# 既に他サイズが登録されている場合はサイズ追加商品
			$output_size_csv->combine($glober_goods_code) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[1]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[2]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[3]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[5]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[6]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), ",";
			$output_size_csv->combine($glober_goods_code[7]) or die $output_size_csv->error_diag();
			print SIZE_ADDITION_FILE $output_size_csv->string(), "\n";
		}
		else {
			$output_sabun_csv->combine($glober_goods_code) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[1]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[2]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[3]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[5]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[6]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), ",";
			$output_sabun_csv->combine($glober_goods_code[7]) or die $output_sabun_csv->error_diag();
			print SABUN_FILE $output_sabun_csv->string(), "\n";
		}
	}
}

$output_sabun_csv->eof;
$output_size_csv->eof;

# ファイルのクローズ			
close(GOODS_FILE);
close(ITEM_FILE);
close(SELECT_FILE);
close(SABUN_FILE);
close(SIZE_ADDITION_FILE);
if ($is_exist_cut_goods_code_file){close(CUT_GOODS_CODE_FILE);}

# 処理終了
output_log("Process is Success!!\n");
output_log("**********END**********\n");

##########################################################################################
##############################  sub routin   #############################################
##########################################################################################
## 指定されたGLOBERのカテゴリ番号に対応するカテゴリ名をXMLファイルから取得する
sub get_category_from_xml {
	my $category_number = $_[0]; 
	#category.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$category_xml_filename",ForceArray=>['category']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_number = $xml_data->{category}[$count]->{g_category_num};
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number eq $xml_category_number){
			$info = $xml_data->{category}[$count]->{y_category_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	return $info;
}

## ログ出力
sub output_log {
	my $day=::to_YYYYMMDD_string();
	print LOG_FILE "[$day]:$_[0]\n";
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}
