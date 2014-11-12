# create_mall_entry_data.pl
# author:T.Aoki
# date:2011/5/14

#========== 改訂履歴 ==========
# date:2012/11/11 modify
# ・以下のファイルの商品番号5桁管理対応
#  -goods_supp.csv
#  -goods_spec.csv
#  -genre_goods.csv
#-----
# date:2012/11/23 modify
# ○サイズチャートの修正
#   ・最後の</tr>が一個多い
#   ・<td><table>が入ってくる時がある
# ○楽天のモバイル用説明文について
#   →楽天「モバイル用商品説明文」、ヤフー「explanation」は、
#    商品コメントのテキストをそのまま引用
#   ・<br />と<tr>を削除
# ○カラー、サイズのスペック表示について
#   ・カラーとサイズの参照はgoods.csv
#    amazon_specとyahooにサイズが入ってこない
# ○「サイズの測り方について」
#   文字化け全ての商品に対して「サイズの測り方について」のリンクをサイズチャートの
#   下に表示
#   ・リンク先の変更(bottomにリンクされている対応)
#   ・ヤフーも同様に変更
#   ※現状はサイズ展開のある商品（7桁）のみにリンクが出力されているかと思います。
#     サイズ展開のない商品（9桁）にも出力して頂けないでしょうか？
# ○9以上の画像に対応
#-----
# date:2014/03/13 addition
# ○商品説明欄に記入のある消費税率バナーのHTMLをカット
#　　・サブルーチンのsub create_r_pc_goods_specの修正
#　　・正規表現で不要な文言を削除
# ○フェリージの認証の店舗URLを置換する
#　　・サブルーチンの楽天店はsub create_r_pc_goods_specの修正
#   ヤフー店はsub create_y_captionの修正
#  ・正規表現でグローバーのURLとHFFのURLを置換
#　○楽天店の商品画像URLを9枚まで表示させるプログラム追記
#  ・サブルーチンのsub create_r_goods_image_urlに9枚までの画像を追記
#
#-----
# date:2014/03/27 addition
# ○楽天のitem.csvに「再入荷お知らせボタン」項目を追加
#　常に1を出力する。
#-----
# date:2014/04/07 addition
# ○楽天のitem.csvに「ポイント変倍率」「ポイント変倍率期間」項目を追加。
# ○brand.xmlの属性「brand_point」と「brand_point_term」を追加。
# ポイント10倍にしたいブランドのbrand_point欄に10を入力する。brand_point_termにはstartday_finishdayを入力する。
# subルーチンを作成。
# ○楽天のitem.csvに「スマートフォン用商品説明文」項目を追加。
# モバイル用商品説明文と同じものにする。
#-----
# date:2014/04/09 addition
# ○yahooのydata.csvの「additional3」項目を修正
# ・ディスプレイにより、実物と色、イメージが異なる事がございます。あらかじめご了承ください。とお直しについてのリンクを追加。
# ○楽天、ヤフーともにサイズチャートの</tr>の重複を削除
# サブルーチンのcreate_r_pc_goods_specとcreate_y_captionの置き換えを修正した。
#　テーブルの最後の</tr></table>→</table>
#
########################################################
## Glober(本店)に登録されている商品をHFF楽天店,Yahoo!店の各モール店
## に登録する為のデータファイルを作成します。 
## 【入力ファイル】
## 本プログラムを実行する際に下記の入力ファイルが実行ディレクトリに存在している必要があります。
## ・goods.csv                                                             
## ・goods_spec.csv
## ・goods_supp.csv
## ・genre_goods.csv
##    -本店に登録されている全商品のデータ。ecbeingよりダウンロード。
## ・sabun_YYYYMMDD.csv
##    -モール店に登録する商品データ。基本的には本店とモール店の差分になります。
##     1カラム目に商品番号が入っている必要があります。
## ・image_num.csv
##    -各商品の画像枚数のデータ。事前にget_image.plで生成。
##     sabun_YYYYMMDD.csvのデータ中SKUのものはまとめられています。
## 【参照ファイル】
## ・brand.xml
## ・category.xml
## ・goods_spec.xml
## 【出力ファイル】
## <楽天用データ>
## ・item.csv
##    -楽天店用登録データ
## ・select.csv
##    -楽天店用バリエーションデータ
## ・item-cat.csv
##    -楽天店用カテゴリ分けデータ
## <Yahoo!店用データ>
## ・y_data.csv
##    -Yahoo!店用登録データ
## ・y_quantity.csv
##    -Yahoo!店用在庫データ
## 【ログファイル】
## ・create_mall_entry_data_yyyymmddhhmmss.log
##    -エラー情報などを出力
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Encode;
use XML::Simple;
use Text::ParseWords;
use Text::CSV_XS;
use File::Path;

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
	print "ERROR!!($!) $log_file_name open failed.\n";
	exit 1;
}

####################
##　入力ファイルの存在チェック
####################
#入力ファイル名
my $input_goods_file_name="goods.csv";
my $input_goods_spec_file_name="goods_spec.csv";
my $input_goods_supp_file_name="goods_supp.csv";
my $input_genre_goods_file_name="genre_goods.csv";
my $input_image_num_file_name="image_num.csv";
my $input_sabun_file_name="";
#入力ファイル配置ディレクトリのオープン
my $current_dir=Cwd::getcwd();
my $input_dir ="$current_dir"."/..";
if (!opendir(INPUT_DIR, "$input_dir")) {
	&output_log("ERROR!!($!) $input_dir open failed.");
	exit 1;
}
#　入力ファイルの有無チェック
my $goods_file_find=0;
my $goods_spec_file_find=0;
my $goods_supp_file_find=0;
my $genre_goods_file_find=0;
my $image_num_file_find=0;
my $sabun_file_find=0;
my $sabun_file_multi=0;
while (my $current_dir_file_name = readdir(INPUT_DIR)){
	if($current_dir_file_name eq $input_goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_spec_file_name) {
		$goods_spec_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_supp_file_name) {
		$goods_supp_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_genre_goods_file_name) {
		$genre_goods_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_image_num_file_name) {
		$image_num_file_find=1;
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
			$input_sabun_file_name=$current_dir_file_name;
		}
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_file_name.\n");
}
if (!$goods_spec_file_find) {
	#goods_spec.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_spec_file_name.\n");
}
if (!$goods_supp_file_find) {
	#goods_supp.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_supp_file_name.\n");
}
if (!$genre_goods_file_find) {
	#genre_goods.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_genre_goods_file_name.\n");
}
if (!$image_num_file_find) {
	#image_num.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_image_num_file_name.\n");
}
if (!$sabun_file_find) {
	#sabun_YYYYMMDD.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist sabun_YYYYMMDD.csv.\n");
}
if ($sabun_file_multi) {
	#sabun_YYYYMMDD.csvファイルがカレントディレクトリに複数存在する
	&output_log("ERROR!! sabun_YYYYMMDD.csv is exist over 2.\n");
}

if (!$goods_file_find || !$goods_spec_file_find || !$goods_supp_file_find || !$genre_goods_file_find || !$image_num_file_find ||
    !$sabun_file_find || $sabun_file_multi) {
	exit 1;
}

####################
##　参照ファイルの存在チェック
####################
my $brand_xml_filename="brand.xml";
my $goods_spec_xml_filename="goods_spec.xml";
my $category_xml_filename="category.xml";
my $r_size_tag_xml_filename="r_size_tag.xml";
#参照ファイル配置ディレクトリのオープン
my $ref_dir ="$current_dir"."/xml";
if (!opendir(REF_DIR, "$ref_dir")) {
	&output_log("ERROR!!($!) $ref_dir open failed.");
	exit 1;
}
#　参照ファイルの有無チェック
my $brand_xml_file_find=0;
my $goods_spec_xml_file_find=0;
my $category_xml_file_find=0;
my $r_size_tag_xml_file_find=0;
while (my $ref_dir_file_name = readdir(REF_DIR)){
	if($ref_dir_file_name eq $brand_xml_filename) {
		$brand_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $goods_spec_xml_filename) {
		$goods_spec_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $category_xml_filename) {
		$category_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $r_size_tag_xml_filename) {
		$r_size_tag_xml_file_find=1;
		next;
	}
}
closedir(REF_DIR);
if (!$brand_xml_file_find) {
	#brand.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $brand_xml_filename.\n");
}
if (!$goods_spec_xml_file_find) {
	#goods_spec.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $goods_spec_xml_filename.\n");
}
if (!$category_xml_file_find) {
	#category.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $category_xml_filename.\n");
}
if (!$r_size_tag_xml_file_find) {
	#r_sizetag.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $r_size_tag_xml_filename.\n");
}
if (!$brand_xml_file_find || !$goods_spec_xml_file_find || !$category_xml_file_find || !$r_size_tag_xml_file_find) {
	exit 1;
}
$brand_xml_filename="$ref_dir"."/"."$brand_xml_filename";
$goods_spec_xml_filename="$ref_dir"."/"."$goods_spec_xml_filename";
$category_xml_filename="$ref_dir"."/"."$category_xml_filename";
$r_size_tag_xml_filename="$ref_dir"."/"."$r_size_tag_xml_filename";

####################
##　入力ファイルのオープン
####################
#CSVファイル用モジュールの初期化
my $input_sabun_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_spec_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_supp_csv = Text::CSV_XS->new({ binary => 1 });
my $input_genre_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_image_num_csv = Text::CSV_XS->new({ binary => 1 });
#入力ファイルのオープン
$input_sabun_file_name="$input_dir"."/"."$input_sabun_file_name";
my $input_sabun_file_disc;
if (!open $input_sabun_file_disc, "<", $input_sabun_file_name) {
	&output_log("ERROR!!($!) $input_sabun_file_name open failed.");
	exit 1;
}	
$input_goods_file_name="$input_dir"."/"."$input_goods_file_name";
my $input_goods_file_disc;
if (!open $input_goods_file_disc, "<", $input_goods_file_name) {
	&output_log("ERROR!!($!) $input_goods_file_name open failed.");
	exit 1;
}	
$input_goods_spec_file_name="$input_dir"."/"."$input_goods_spec_file_name";
my $input_goods_spec_file_disc;
if (!open $input_goods_spec_file_disc, "<", $input_goods_spec_file_name) {
	&output_log("ERROR!!($!) $input_goods_spec_file_name open failed.");
	exit 1;
}	
$input_goods_supp_file_name="$input_dir"."/"."$input_goods_supp_file_name";
my $input_goods_supp_file_disc;
if (!open $input_goods_supp_file_disc, "<", $input_goods_supp_file_name) {
	&output_log("ERROR!!($!) $input_goods_supp_file_name open failed.");
	exit 1;
}	
$input_genre_goods_file_name="$input_dir"."/"."$input_genre_goods_file_name";
my $input_genre_goods_file_disc;
if (!open $input_genre_goods_file_disc, "<", $input_genre_goods_file_name) {
	&output_log("ERROR!!($!) $input_genre_goods_file_name open failed.");
	exit 1;
}	
$input_image_num_file_name="$input_dir"."/"."$input_image_num_file_name";
my $input_image_num_file_disc;
if (!open $input_image_num_file_disc, "<", $input_image_num_file_name) {
	&output_log("ERROR!!($!) $input_image_num_file_name open failed.");
	exit 1;
}	

####################
##　出力ファイルのオープン
####################
#出力ディレクトリ
my $output_rakuten_data_dir="../rakuten_up_data";
my $output_yahoo_data_dir="../yahoo_up_data";
#出力ファイル名
my $output_item_file_name="$output_rakuten_data_dir"."/"."item.csv";
my $output_select_file_name="$output_rakuten_data_dir"."/"."select.csv";
my $output_itemcat_file_name="$output_rakuten_data_dir"."/"."item-cat.csv";
my $output_ydata_file_name="$output_yahoo_data_dir"."/"."ydata.csv";
my $output_yquantity_file_name="$output_yahoo_data_dir"."/"."yquantity.csv";
#出力先ディレクトリの作成
unless(-d $output_rakuten_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_rakuten_data_dir)) {
		output_log("ERROR!!($!) $output_rakuten_data_dir create failed.");
		exit 1;
	}
}
unless(-d $output_yahoo_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_yahoo_data_dir)) {
		output_log("ERROR!!($!) $output_yahoo_data_dir create failed.");
		exit 1;
	}
}
#出力用CSVファイルモジュールの初期化
my $output_item_csv = Text::CSV_XS->new({ binary => 1 });
my $output_select_csv = Text::CSV_XS->new({ binary => 1 });
my $output_itemcat_csv = Text::CSV_XS->new({ binary => 1 });
my $output_ydata_csv = Text::CSV_XS->new({ binary => 1 });
my $output_yquantity_csv = Text::CSV_XS->new({ binary => 1 });
#出力ファイルのオープン
my $output_item_file_disc;
if (!open $output_item_file_disc, ">", $output_item_file_name) {
	&output_log("ERROR!!($!) $output_item_file_name open failed.");
	exit 1;
}	
my $output_select_file_disc;
if (!open $output_select_file_disc, ">", $output_select_file_name) {
	&output_log("ERROR!!($!) $output_select_file_name open failed.");
	exit 1;
}	
my $output_itemcat_file_disc;
if (!open $output_itemcat_file_disc, ">", $output_itemcat_file_name) {
	&output_log("ERROR!!($!) $output_itemcat_file_name open failed.");
	exit 1;
}	
my $output_ydata_file_disc;
if (!open $output_ydata_file_disc, ">", $output_ydata_file_name) {
	&output_log("ERROR!!($!) $output_ydata_file_name open failed.");
	exit 1;
}	
my $output_yquantity_file_disc;
if (!open $output_yquantity_file_disc, ">", $output_yquantity_file_name) {
	&output_log("ERROR!!($!) $output_yquantity_file_name open failed.");
	exit 1;
}	

####################
## 各関数間に跨って使用するグローバル変数
####################
our @global_entry_goods_info;
our %global_entry_goods_size_info;
our @global_entry_goods_supp_info;
our @global_entry_goods_spec_info;
our %global_entry_genre_goods_info;
our $global_category_priority=1;

## Yahoo!のydata.csv:relevant_linksデータ用にデータを保持
our @global_item_list=<$input_image_num_file_disc>;
seek $input_image_num_file_disc,0,0;
## スペック情報のソート順を保持
our @globel_spec_sort=&get_spec_sort_from_xml();

########################################################################################################################
##########################　処理開始
########################################################################################################################
&output_log("**********START**********\n");
# 楽天用の出力CSVファイルに項目名を出力
&add_r_csv_name();
# Yahoo!用の出力CSVファイルに項目名を出力
&add_y_csv_name();
# 商品データの作成
while(my $image_num_line = $input_image_num_csv->getline($input_image_num_file_disc)){
	##### goods.csvファイルの読み出し
	my $entry_goods_code=@$image_num_line[0];
	# goodsファイルの読み出し(項目行分1行読み飛ばし)
	seek $input_goods_file_disc,0,0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	@global_entry_goods_info=();
	%global_entry_goods_size_info=();
	my $is_find_goods_info=0;
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){	
		# 登録情報から商品コード読み出し
		my $goods_code_9=@$goods_line[0];
		my $goods_code="";
		if (length($entry_goods_code) == 7) {
			# SKUなので7桁で比較
			# 商品コードの上位7桁を切り出し
			$goods_code=substr($goods_code_9, 0, 7);
		}
		else {$goods_code=$goods_code_9;}		
		# 商品コードが合致したらコードを保持する
		if ($entry_goods_code eq $goods_code) {
			if (!$is_find_goods_info) {
				# goods.cvsの商品情報を保持(SKUのものは一つ目に合致した商品の情報を保持)
				push(@global_entry_goods_info,($entry_goods_code,@$goods_line[1],@$goods_line[2],@$goods_line[3],@$goods_line[5],@$goods_line[6], @$goods_line[11]));
				$is_find_goods_info=1;
			}				
			if (length($entry_goods_code) == 7) {
				# 7桁の場合は全ての商品のサイズ情報を保持する
				# サイズの保持
				$global_entry_goods_size_info{$goods_code_9}=@$goods_line[5];	
			}
			else {
				# 通常商品の場合は情報を取得して終了
				last;
			}
		}
	}
	# ファイルに商品がない場合は出力しない
	if (!$is_find_goods_info) {
		output_log("Not Exist $entry_goods_code in goods.csv.\n");
		next;
	}

	##### goods_suppファイルの読み出し
	@global_entry_goods_supp_info=();
	seek $input_goods_supp_file_disc,0,0;
	my $goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc);
	while($goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc)){
		my $goods_supp_code_5 = @$goods_supp_line[0];
		# 商品コードの上位5桁を切り出し
		my $entry_goods_code_5=substr($entry_goods_code, 0, 5);
		# 商品コードが合致したらコードを保持する
		if ($entry_goods_code_5 eq $goods_supp_code_5) {
			# goods_supp.cvsの商品情報を保持(SKUのものは一つ目に合致した商品の情報を保持)
			push(@global_entry_goods_supp_info, (@$goods_supp_line[1],@$goods_supp_line[2]));
			last;
		}
	}

	##### goods_specファイルの読み出し
	@global_entry_goods_spec_info=();
	# SKUの場合はsabun_YYYYMMDD.csvに含まれている商品コード分の情報を読み出す
	if (length($entry_goods_code) == 7) {
		my $is_first=1;
		# 差分ファイルから登録する商品コードを取得する
		seek $input_sabun_file_disc,0,0;
		my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
		while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){	
			my $sabun_code_9=@$sabun_line[0];
			# 上位7桁を切り出す
			my $sabun_code_7=substr($sabun_code_9, 0, 7);
			# 合致している場合はその商品コードの情報を取得
			if ($entry_goods_code eq $sabun_code_7) {
				# 商品コードの上位5桁を切り出し
				my $sabun_code_5=substr($sabun_code_9, 0, 5);
				seek $input_goods_spec_file_disc,0,0;
				my $goods_spec_line=$input_goods_spec_csv->getline($input_goods_spec_file_disc);
				while($goods_spec_line = $input_goods_spec_csv->getline($input_goods_spec_file_disc)){	
					# サイズ情報の改行コード削除
					chomp @$goods_spec_line[2];
					# 一つの商品のスペック情報を保持する(5桁で比較)	
					if ($sabun_code_5 eq @$goods_spec_line[0]) {
						if ($is_first) {
							push(@global_entry_goods_spec_info, (@$goods_spec_line[1], @$goods_spec_line[2]));
						}
					}
				}
				# スペック情報保持完了
				if($is_first){$is_first=0;}
			}
		}
	}
	else {
		# 商品コードの上位5桁を切り出し
		my $entry_goods_code_5=substr($entry_goods_code, 0, 5);
		seek $input_goods_spec_file_disc,0,0;
		my $goods_spec_line=$input_goods_spec_csv->getline($input_goods_spec_file_disc);
		while($goods_spec_line = $input_goods_spec_csv->getline($input_goods_spec_file_disc)){	
			# 登録情報から商品コード読み出し
			if ($entry_goods_code_5 eq @$goods_spec_line[0]) {
				# 商品のスペック情報を保持する
				push(@global_entry_goods_spec_info, (@$goods_spec_line[1], @$goods_spec_line[2]));

			}
		}
	}

	##### genre_goodsの読み出し
	# 商品コードの上位5桁を切り出し
	my $entry_goods_code_5=substr($entry_goods_code, 0, 5);
	seek $input_genre_goods_file_disc,0,0;
	%global_entry_genre_goods_info=();
	# 1行読み飛ばし
	my $genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc);
	my $genre_goods_count=0;
	while($genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc)){	
		if (($entry_goods_code_5==@$genre_goods_line[1]) && (length(@$genre_goods_line[0])==4)) {
			# 商品番号(SKUの場合は1商品)が合致した場合は、カテゴリ番号を保持する
			$global_entry_genre_goods_info{$genre_goods_count}=@$genre_goods_line[0];
			$genre_goods_count++;
		}
	}

	# 楽天用データを追加
	&add_rakuten_data();
	# Yahoo!用データを追加
#	&add_yahoo_data();
}

# 処理終了
output_log("Process is Success!!\n");
output_log("**********END**********\n");

# 入力用CSVファイルモジュールの終了処理
$input_sabun_csv->eof;
$input_goods_csv->eof;
$input_goods_spec_csv->eof;
$input_goods_supp_csv->eof;
$input_genre_goods_csv->eof;
$input_image_num_csv->eof;
# 出力用CSVファイルモジュールの終了処理
$output_item_csv->eof;
$output_select_csv->eof;
$output_itemcat_csv->eof;
$output_ydata_csv->eof;
$output_yquantity_csv->eof;
# 入力ファイルのクローズ
close $input_sabun_file_disc;
close $input_goods_file_disc;
close $input_goods_spec_file_disc;
close $input_goods_supp_file_disc;
close $input_genre_goods_file_disc;
close $input_image_num_file_disc;
# 出力ファイルのクローズ
close $output_item_file_disc;
close $output_select_file_disc;
close $output_itemcat_file_disc;
close $output_ydata_file_disc;
close $output_yquantity_file_disc;
close(LOG_FILE);


##############################
## 楽天用ファイルに項目名を追加
##############################
sub add_r_csv_name {
	# 楽天用のitem.csvに項目名を出力
	&add_r_itemcsv_name();
	# 楽天用のselect.csvに項目名を出力
	&add_r_selectcsv_name();
	# 楽天用のitem-cat.csvに項目名を出力
	&add_r_itemcatcsv_name();
	return 0;
}

##############################
## 楽天用item.csvファイルに項目名を追加
##############################
sub add_r_itemcsv_name {
	my @csv_r_item_name=("コントロールカラム","商品管理番号（商品URL）","商品番号","全商品ディレクトリID","タグID","PC用キャッチコピー","モバイル用キャッチコピー","商品名","販売価格","表示価格","送料","商品情報レイアウト","PC用商品説明文","モバイル用商品説明文","スマートフォン用商品説明文","PC用販売説明文","商品画像URL","在庫タイプ","在庫数","在庫数表示","項目選択肢別在庫用横軸項目名","項目選択肢別在庫用縦軸項目名","在庫あり時納期管理番号","あす楽配送管理番号","再入荷お知らせボタン","ポイント変倍率","ポイント変倍率適用期間");
	my $csv_r_item_name_num=@csv_r_item_name;
	my $csv_r_item_name_count=0;
	for my $csv_r_item_name_str (@csv_r_item_name) {
		Encode::from_to( $csv_r_item_name_str, 'utf8', 'shiftjis' );
		$output_item_csv->combine($csv_r_item_name_str) or die $output_item_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_item_name_count >= $csv_r_item_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_item_file_disc $output_item_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用select.csvファイルに項目名を追加
##############################
sub add_r_selectcsv_name {
	my @csv_r_select_name=("項目選択肢用コントロールカラム","商品管理番号（商品URL）","選択肢タイプ","Select/Checkbox用項目名","Select/Checkbox用選択肢","項目選択肢別在庫用横軸選択肢","項目選択肢別在庫用横軸選択肢子番号","項目選択肢別在庫用縦軸選択肢","項目選択肢別在庫用縦軸選択肢子番号","項目選択肢別在庫用取り寄せ可能表示","項目選択肢別在庫用在庫数","在庫戻しフラグ","在庫切れ時の注文受付","在庫あり時納期管理番号","在庫切れ時納期管理番号");
	my $csv_r_select_name_num=@csv_r_select_name;
	my $csv_r_select_name_count=0;
	for my $csv_r_select_name_str (@csv_r_select_name) {
		Encode::from_to( $csv_r_select_name_str, 'utf8', 'shiftjis' );
		$output_select_csv->combine($csv_r_select_name_str) or die $output_select_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_select_name_count >= $csv_r_select_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_select_file_disc $output_select_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用item-cat.csvファイルに項目名を追加
##############################
sub add_r_itemcatcsv_name {
	my @csv_r_itemcat_name=("コントロールカラム","商品管理番号（商品URL）","商品名","表示先カテゴリ","優先度","URL","1ページ複数形式");
	my $csv_r_itemcat_name_num=@csv_r_itemcat_name;
	my $csv_r_itemcat_name_count=0;
	for my $csv_r_itemcat_name_str (@csv_r_itemcat_name) {
		Encode::from_to( $csv_r_itemcat_name_str, 'utf8', 'shiftjis' );
		$output_itemcat_csv->combine($csv_r_itemcat_name_str) or die $output_itemcat_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_itemcat_name_count >= $csv_r_itemcat_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_itemcat_file_disc $output_itemcat_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## Yahoo用ファイルに項目名を追加
##############################
sub add_y_csv_name {
	# Yahoo用のydata.csvに項目名を出力
	&add_y_datacsv_name();
	# Yahoo用のyquantity.csvに項目名を出力
	&add_y_quantitycsv_name();
	return 0;
}

##############################
## Yahoo用ydata.csvファイルに項目名を追加
##############################
sub add_y_datacsv_name {
	my @csv_y_data_name=("path","name","code","sub-code","original-price","price","sale-price","options","headline","caption","abstract","explanation","additional1","additional2","additional3","relevant-links","ship-weight","taxable","release-date","point-code","meta-key","meta-desc","template","sale-period-start","sale-period-end","sale-limit","sp-code","brand-code","person-code","yahoo-product-code","product-code","jan","isbn","delivery","product-category","spec1","spec2","spec3","spec4","spec5","display","astk-code");
	my $csv_y_data_name_num=@csv_y_data_name;
	my $csv_y_data_name_count=0;
	for my $csv_y_data_name_str (@csv_y_data_name) {
		$output_ydata_csv->combine($csv_y_data_name_str) or die $output_ydata_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_y_data_name_count >= $csv_y_data_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_ydata_file_disc $output_ydata_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## Yahoo用yquantity.csvファイルに項目名を追加
##############################
sub add_y_quantitycsv_name {
	my @csv_y_quantity_name=("code","sub-code","sp-code","quantity");
	my $csv_y_quantity_name_num=@csv_y_quantity_name;
	my $csv_y_quantity_name_count=0;
	for my $csv_y_quantity_name_str (@csv_y_quantity_name) {
		$output_yquantity_csv->combine($csv_y_quantity_name_str) or die $output_yquantity_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_y_quantity_name_count >= $csv_y_quantity_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_yquantity_file_disc $output_yquantity_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用CSVファイルにデータを追加
##############################
sub add_rakuten_data {
	# item.csvにデータを追加
	&add_rakuten_item_data();
	# select.csvにデータを追加
#	&add_rakuten_select_data();
	# item-cat.csvにデータを追加
#	&add_rakuten_itemcat_data();
	return 0;
}

##############################
## 楽天用item.CSVファイルにデータを追加
##############################
sub add_rakuten_item_data {
	# 各値をCSVファイルに書き出す
	# コントロールカラム
	$output_item_csv->combine("n") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品管理番号
	$output_item_csv->combine($global_entry_goods_info[0]) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品番号
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 全商品ディレクトリ(手動で入力する必要がある)
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# タグID
	my $tag_id="";
	if (length($global_entry_goods_info[0]) == 7) {
		# SKUの場合はサイズのtagidを出力
		$tag_id=&create_r_tag_id();
	}
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用キャッチコピー
	$output_item_csv->combine(&create_r_pccatch_copy()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# モバイル用キャッチコピー
	$output_item_csv->combine(&create_r_mbcatch_copy()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品名
	$output_item_csv->combine(&create_ry_goods_name()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 販売価格
	$output_item_csv->combine($global_entry_goods_info[3]) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 表示価格
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 送料
	my $output_postage_str="";
	if ($global_entry_goods_info[3] >= 5000) {$output_postage_str="1";}
	else {$output_postage_str="0";}
	$output_item_csv->combine($output_postage_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品情報レイアウト
	$output_item_csv->combine("6") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用商品説明文
	$output_item_csv->combine(&create_r_pc_goods_spec()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# モバイル用商品説明文
	$output_item_csv->combine(&create_ry_mb_goods_spec()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# スマートフォン用商品説明文
	$output_item_csv->combine(&create_ry_smp_goods_spec()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用販売説明文
	$output_item_csv->combine(&create_r_pc_goods_detail()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品画像URL
	$output_item_csv->combine(&create_r_goods_image_url()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫タイプ
	my $output_stocktype_str="";
	if (length($global_entry_goods_info[0]) == 7) {$output_stocktype_str="2";}
	else {$output_stocktype_str="1";}
	$output_item_csv->combine($output_stocktype_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫数
	my $output_stocknum_str="";
	if (length($global_entry_goods_info[0]) == 7) {$output_stocknum_str="";}
	else {$output_stocknum_str="0";}
	$output_item_csv->combine($output_stocknum_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫数表示
	my $output_stockdisplay_str="";
	if (length($global_entry_goods_info[0]) == 7) {$output_stockdisplay_str="";}
	else {$output_stockdisplay_str="0";}
	$output_item_csv->combine($output_stockdisplay_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 項目選択肢別在庫用横軸項目名
	my $output_stockitem_str="";
	if (length($global_entry_goods_info[0]) == 7) {$output_stockitem_str="サイズ";}
	else {$output_stockitem_str="";}
	Encode::from_to( $output_stockitem_str, 'utf8', 'shiftjis' );
	$output_item_csv->combine($output_stockitem_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 項目選択肢別在庫用縦軸項目名
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫あり時納期管理番号
	my $output_stockcode_str="";
	if (length($global_entry_goods_info[0]) == 7) {$output_stockcode_str="";}
	else {$output_stockcode_str="14";}
	$output_item_csv->combine($output_stockcode_str) or die $output_item_csv->error_diag();
=pod
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
=cut
	print $output_item_file_disc $output_item_csv->string(), ",";
	# あす楽配送管理番号
	$output_item_csv->combine("1") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 再入荷お知らせボタン
	$output_item_csv->combine("1") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# ポイント変倍率
	$output_item_csv->combine(&create_r_point()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# ポイント変倍率適用期間
	$output_item_csv->combine(&create_r_point_term()) or die $output_item_csv->error_diag();
	#最後に改行を追加
	print $output_item_file_disc $output_item_csv->string(), "\n";
	return 0;
}

##############################
## 楽天用select.csvファイルにデータを追加
##############################
sub add_rakuten_select_data {
	# SKU(7桁)の商品のみ追加
	if (length($global_entry_goods_info[0]) == 7) {
		# 各値をCSVファイルに書き出す
		# 全てのサイズを追加する
		foreach my $goods_code_9 ( sort keys %global_entry_goods_size_info ) {
			# 項目選択肢用コントロールカラム
			$output_select_csv->combine("n") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 商品管理番号（商品URL）
			$output_select_csv->combine($global_entry_goods_info[0]) or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 選択肢タイプ
			$output_select_csv->combine("i") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# Select/Checkbox用項目名
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# Select/Checkbox用選択肢
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用横軸選択肢
			$output_select_csv->combine($global_entry_goods_size_info{$goods_code_9}) or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用横軸選択肢子番号
			$output_select_csv->combine(substr($goods_code_9, 7, 2)) or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用縦軸選択肢
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用縦軸選択肢子番号
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用取り寄せ可能表示
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 項目選択肢別在庫用在庫数
			$output_select_csv->combine("0") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 在庫戻しフラグ
			$output_select_csv->combine("0") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 在庫切れ時の注文受付
			$output_select_csv->combine("0") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 在庫あり時納期管理番号
			$output_select_csv->combine("14") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), ",";
			# 在庫切れ時納期管理番号
			$output_select_csv->combine("") or die $output_select_csv->error_diag();
			print $output_select_file_disc $output_select_csv->string(), "\n";
		}
	}
	return 0;
}

##############################
## 楽天用item-cat.csvファイルにデータを追加
##############################
sub add_rakuten_itemcat_data {
	# 各値をファイルに出力する	
	# 表示先カテゴリの出力
	# "アイテムをチェック"
	foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
		# コントロールカラム
		$output_itemcat_csv->combine("n") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 商品管理番号（商品URL）
		$output_itemcat_csv->combine("$global_entry_goods_info[0]") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 商品名
		$output_itemcat_csv->combine(&create_ry_goods_name()) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 表示先カテゴリ
		chomp $global_entry_genre_goods_info{$genre_goods_num};
		$output_itemcat_csv->combine(&get_r_category_from_xml($global_entry_genre_goods_info{$genre_goods_num}, 0)) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 優先度
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# URL
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 1ページ複数形式
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), "\n";
	}
	# "ブランドをチェック"
	# コントロールカラム
	$output_itemcat_csv->combine("n") or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	# 商品管理番号（商品URL）
	$output_itemcat_csv->combine("$global_entry_goods_info[0]") or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	# 商品名
	$output_itemcat_csv->combine(&create_ry_goods_name()) or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	# 表示先カテゴリ
	$output_itemcat_csv->combine(&get_info_from_xml("r_category")) or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	# 優先度
	$output_itemcat_csv->combine("$global_category_priority") or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	$global_category_priority++;
	# URL
	$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
	# 1ページ複数形式
	$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
	print $output_itemcat_file_disc $output_itemcat_csv->string(), "\n";
	return 0;
}

##############################
## Yahoo!用CSVファイルにデータを追加
##############################
sub add_yahoo_data {
	# Yahoo用のydata.csvにデータを追加
	&add_ydata_data();
	# Yahoo用のyquantity.csvにデータを追加
	&add_yquantity_data();
	
	return 0;
}

##############################
## Yahoo!用ydata.csvファイルにデータを追加
##############################
sub add_ydata_data {
	# 各値をCSVファイルに書き出す
	# path
	$output_ydata_csv->combine(&create_y_path()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# name
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# code
	$output_ydata_csv->combine($global_entry_goods_info[0]) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sub-code
	$output_ydata_csv->combine(&create_y_subcode()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# original-price
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# price
	$output_ydata_csv->combine($global_entry_goods_info[3]) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-price
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# options
	$output_ydata_csv->combine(&create_y_options()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# headline
	$output_ydata_csv->combine(&create_y_headline()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# caption
	$output_ydata_csv->combine(&create_y_caption()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# abstract
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# explanation
	$output_ydata_csv->combine(&create_y_explanation()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional1
	$output_ydata_csv->combine(&create_y_additional1()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional2
	$output_ydata_csv->combine(&create_y_additional2()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional3
	$output_ydata_csv->combine(&create_y_additional3()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# relevant-links
	$output_ydata_csv->combine(&create_y_relevant_links()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# ship-weight
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# taxable
	$output_ydata_csv->combine("1") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# release-date
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# point-code
	$output_ydata_csv->combine(&create_r_point()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# meta-key
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# meta-desc
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# template
	$output_ydata_csv->combine("IT02") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-period-start
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-period-end
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-limit
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sp-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# brand-code(T.B.D 自動化検討)
	$output_ydata_csv->combine(&get_info_from_xml("y_brand_code")) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# person-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# yahoo-product-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# product-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# jan
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# isbn
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# delivery
	my $output_delivery_str="";
	if ($global_entry_goods_info[3] >= 5000) {$output_delivery_str="1";}
	else {$output_delivery_str="0";}
	$output_ydata_csv->combine($output_delivery_str) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# product-category(T.B.D 手動で入力)
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec1
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec2
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec3
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec4
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec5
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# display
	$output_ydata_csv->combine("1") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# astk-code
	$output_ydata_csv->combine("2") or die $output_ydata_csv->error_diag();
	#最後に改行を追加
	print $output_ydata_file_disc $output_ydata_csv->string(), "\n";
	return 0;
}

##############################
## Yahoo!用yquantity.csvファイルにデータを追加
##############################
sub add_yquantity_data {
	# 各値をファイルに出力する	
	if (length($global_entry_goods_info[0]) == 9) {
		# code
		$output_yquantity_csv->combine($global_entry_goods_info[0]) or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# sub-code
		$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# sp-code
		$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# quantity
		$output_yquantity_csv->combine("0") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), "\n";
	}
	else {
		# 差分ファイルから登録する商品コードを取得する
		seek $input_sabun_file_disc,0,0;
		my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
		while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){	
			my $sabun_code_9=@$sabun_line[0];
			# 上位7桁を切り出す
			my $sabun_code=substr($sabun_code_9, 0, 7);
			# 合致している場合はその商品コードの情報を取得
			if ($global_entry_goods_info[0] eq $sabun_code) {
				# code
				$output_yquantity_csv->combine($global_entry_goods_info[0]) or die $output_yquantity_csv->error_diag();
				print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
				# sub-code
				$output_yquantity_csv->combine($sabun_code_9) or die $output_yquantity_csv->error_diag();
				print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
				# sp-code
				$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
				print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
				# quantity
				$output_yquantity_csv->combine("0") or die $output_yquantity_csv->error_diag();
				print $output_yquantity_file_disc $output_yquantity_csv->string(), "\n";
			}
		}
	}
	
	return 0;
}

#########################
###楽天用データ作成関数　###
#########################

##############################
## (楽天)タグIDの生成
##############################
sub create_r_tag_id {
	my $tag_id="";
	foreach my $genre_goods_code_tmp ( sort keys %global_entry_genre_goods_info ) {
		foreach my $goods_size_code_tmp ( sort keys %global_entry_goods_size_info ) {
			if ($tag_id ne "") {
				$tag_id .= "/";
			}
			$tag_id .= &get_r_sizetag_from_xml($global_entry_genre_goods_info{$genre_goods_code_tmp}, $global_entry_goods_size_info{$goods_size_code_tmp});
		}
	}
	return $tag_id;
}

##############################
## (楽天)PC用キャッチコピーの生成
##############################
sub create_r_pccatch_copy {
	# キャッチコピーデータの作成
	my $catch_copy = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_info[1] eq $str_clober_collection) {
		$catch_copy=&get_info_from_xml("brand_name");
	}
	else {
		$catch_copy=$global_entry_goods_info[1];
	}
	# カテゴリ名を取得し付加する
	foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
		my $r_category_name = &get_r_category_from_xml($global_entry_genre_goods_info{$genre_goods_num}, 1);
		if ($r_category_name ne "") {
			$catch_copy .= " "."$r_category_name";
		}
	}
	# 定型文言
	my $jstr1="【レビューで商品券】【正規販売店】【代引き手数料無料】【当日お届け】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_info[3] >= 5000) {
	  my $jstr2="【送料無料】";
	  Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
	  $catch_copy .= "$jstr2";
	}
	# あす楽対応文言
	my $jstr3="【あす楽対応】";
	Encode::from_to( $jstr3, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr3";
	# 最後に改行コードを追加
	$catch_copy .= "<br />";
	return $catch_copy;
}

##############################
## (楽天)MB用キャッチコピーの生成
##############################
sub create_r_mbcatch_copy {
	# キャッチコピーデータの作成
	my $catch_copy = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_info[1] eq $str_clober_collection) {
		$catch_copy=&get_info_from_xml("brand_name");
	}
	else {
		$catch_copy=$global_entry_goods_info[1];
	}
	# 定型文言
	my $jstr1="【正規販売店】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_info[3] >= 5000) {
	  my $jstr2="【送料無料】";
	  Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
	  $catch_copy .= "$jstr2";
	}
=pod    # あす楽対応文言は文字数制限に引っかかるので付加しない
	# あす楽対応文言
	my $jstr3="【あす楽対応】";
	Encode::from_to( $jstr3, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr3";
=cut
	return $catch_copy;
}

##############################
## (楽天)商品名の生成
##############################
sub create_ry_goods_name {
	# カテゴリ名称からブランド名を取得
	my $brand_name = &get_info_from_xml("brand_name");
	# 商品名を生成
	my $goods_name = "$brand_name".":"."$global_entry_goods_info[2]"." "."$global_entry_goods_info[5]";
	return $goods_name;
}

##############################
## (楽天)PC用説明文の生成
##############################
sub create_r_pc_goods_spec {
	# 商品説明文格納用
	my $spec_str="";

my $html_str1=
<<"HTML_STR_1";
<style type="text/css">
<!--
body{font-size:12px;color:#333333;line-height:150%;}
td{font-size:12px;color:#333333;line-height:150%;}
a:link,a:visited{color:#333333;}
a:active,a:hover{color:#666666;}
a img {border:none;}
h1 {font-family: "MS UI Gothic";font-size: 18px;line-height: 130%;text-decoration:none;margin:0;padding:0;}
#sizeChart {margin-top:10px;border-collapse:collapse;}
#sizeChart th{background-color:#EEE;}
#sizeChart th,#sizeChart td{font-size:12px;font-weight:normal;text-align:center;padding:2px 0px;border:1px solid #808080;}
ul.link1 {margin:0;padding:15px 0 5px;background:url(http://www.rakuten.ne.jp/gold/hff/image/bg_dot3.gif) repeat-x top left;}
ul.link1 li {list-style:none;padding:0 15px;margin:0 0 3px 0;background:url(http://www.rakuten.ne.jp/gold/hff/image/button.gif) no-repeat 0 1;}
.clear {clear:both;}
-->
</style>
<table width="600" border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td><a href="http://event.rakuten.co.jp/asuraku/about/" target="_blank"><img src="http://www.rakuten.ne.jp/gold/hff/image/h_banaasuraku3.gif" border="0" alt="あす楽"></a><br /><a href="http://www.rakuten.ne.jp/gold/hff/review/review2014.html" target="_blank"><img src="http://www.rakuten.ne.jp/gold/hff/review/new_review2014.gif" border="0" alt="レビューキャンペーン"></a><br /><br /></td>
  </tr>
  <tr>
</table>
<table width="600" border="0" cellpadding="0" cellspacing="0">
<tr>
<td width="300" valign="top">
<img src="http://www.rakuten.ne.jp/gold/hff/image/products_title.gif" border="0" alt="PRODUCT"><br />
<table width="290" border="0" cellpadding="2" cellspacing="0">
<tr>
<td>
HTML_STR_1
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
	# HTML文1を追加
	$spec_str .= "$html_str1";
	
	
	# 商品コメント1を追加
	my $goods_comment_1 = $global_entry_goods_supp_info[0];
	my $after_rep_str0="";
	my $before_rep_str0="<ul class=\"link1\">.*<\/ul>";
	$goods_comment_1 =~ s/$before_rep_str0/$after_rep_str0/g;
	#　消費税増税バナーを削除
	my $after_rep_str1="";
	my $before_rep_str1="<br \/><br \/><p>.*<\/p>";	
	$goods_comment_1 =~ s/$before_rep_str1/$after_rep_str1/g;	
	#　<span class="itemComment">を削除
	my $after_rep_str2="";
	my $before_rep_str2="<span class=\"itemComment\">";
	$goods_comment_1 =~ s/$before_rep_str2/$after_rep_str2/g;
	#　</span>を削除
	my $after_rep_str3="";
	my $before_rep_str3="</span>";
	$goods_comment_1 =~ s/$before_rep_str3/$after_rep_str3/g;
	# フェリージのリンク変換1
	my $after_rep_str4="<a href=\"http://link.rakuten.co.jp/0/048/566/";
	my $before_rep_str4="<a href=\"http://seal.*FCS&f2=glober.jp";
	$goods_comment_1 =~ s/$before_rep_str4/$after_rep_str4/g;
	# フェリージのリンク変換2
	my $after_rep_str5="http://image.rakuten.co.jp/hff/cabinet/pic/felisi/felisi_seal.gif";
	my $before_rep_str5="http://seal.felisi.net/FCSSeal/images/fcs_230x60_json.gif";
	$goods_comment_1 =~ s/$before_rep_str5/$after_rep_str5/g;
	# フォックスのリンク変換
	my $after_rep_str6="http://www.rakuten.ne.jp/gold/hff/brand/foxumbrellas/fx_repair.html";
	my $before_rep_str6="http://blog.glober.jp.*1526#repair";
	$goods_comment_1 =~ s/$before_rep_str6/$after_rep_str6/;
	# ジョンストンズのリンク削除
	my $after_rep_str7="";
	my $before_rep_str7="<br /><br />.*alt=\"johnstons\">";
	Encode::from_to( $before_rep_str7, 'utf8', 'shiftjis' );
	$goods_comment_1 =~ s/$before_rep_str7/$after_rep_str7/g;
	# 商品コメント1を追加
	$spec_str .= "$goods_comment_1";
	# ブランド辞典を追加
	my $brand_dic = &get_info_from_xml("r_dictionary");
	if ($brand_dic ne "") {
		$spec_str="$spec_str"."$brand_dic";
	}

	# 商品スペックは一つ目の商品のものを使用
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}

my $html_str2=
<<"HTML_STR_2";
</td>
</table></td>
<td valign="top"><div style="color:#333333; padding:0px; margin-bottom:10px;">
<table width="300" cellpadding="5" cellspacing="1">
<tr bgcolor="#eeeeee">
<td width=80>商品番号</td>
<td>
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );

my $html_str3=
<<"HTML_STR_3";
</td>
</tr>
<tr bgcolor="#eeeeee">
<td>
HTML_STR_3

my $html_str4=
<<"HTML_STR_4";
</td>
<td>
HTML_STR_4

	# 商品番号を追加
	$spec_str .= "$html_str2"."$global_entry_goods_info[0]";	
	# カラーを追加
	if ($global_entry_goods_info[5] ne "") {
		my $color_str = "カラー";
		Encode::from_to( $color_str, 'utf8', 'shiftjis' );
		$spec_str .= "$html_str3"."$color_str"."$html_str4"."$global_entry_goods_info[5]";	
	}
	# サイズを追加
	my $size_str = "サイズ";
	Encode::from_to( $size_str, 'utf8', 'shiftjis' );
	if (keys(%global_entry_goods_size_info) != 0) {
		my $size_goods_str="";
		foreach my $size_goods_code (sort keys %global_entry_goods_size_info) {
			my $add_size_str="";
			if ($size_goods_str ne "") {
				$add_size_str=" ";		
			}
			$size_goods_str .= "$add_size_str"."$global_entry_goods_size_info{$size_goods_code}";
		}
		$spec_str .= "$html_str3"."$size_str"."$html_str4"."$size_goods_str";
	}
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		$spec_str .= "$html_str3"."$specs[$i]"."$html_str4"."$specs[$i+1]";
	}
	# 不要→メーカーコードがある場合はスペックの最後に追加
=pod 拡張項目のメーカー品番を使用するため、↑不要
	if ($global_entry_goods_info[6] ne "") {
		my $maker_code = "メーカー品番";
		Encode::from_to( $maker_code, 'utf8', 'shiftjis' );
		$spec_str .= "$html_str3"."$maker_code"."$html_str4"."$global_entry_goods_info[6]";
	}
=cut
my $html_str5=
<<"HTML_STR_5";
</td>
</tr>
</table>
</div>
HTML_STR_5
	# HTML文5(タグ閉じ)を追加
	$spec_str="$spec_str$html_str5";

	# 商品コメント2を取得
	my $goods_info = $global_entry_goods_supp_info[1];
	# サイズの測り方についての文字列定義
	my $size_info = "サイズの測り方について";
	Encode::from_to( $size_info, 'utf8', 'shiftjis' );
	# 商品コメント2が無い場合はサイズの測り方についてのリンクを追加
	if ($goods_info eq "") {
		$spec_str .= "<div style='margin-top:3px;text-align:right;'><a href='http://www.rakuten.ne.jp/gold/hff/howto-size' target='_blank'>$size_info<img src='http://www.rakuten.ne.jp/gold/hff/image/window.gif'  /></a></div>";
	}
	else {
		# 楽天用にコメント修正
		my $after_rep_str1="<table width='300' border='0' cellpadding='5' cellspacing='0' style='text-align:left; border:1px solid #CCCCCC;border-bottom:none;border-right:none;'>";
		my $before_rep_str1_1_1="<table class=\"infoTable\"><tr><td><table>";
		$goods_info =~ s/$before_rep_str1_1_1/$after_rep_str1/g;
		my $before_rep_str1_1_2=
<<"HTML_STR_1_1_2";
<table class="infoTable">
<tr>
<td><table>
HTML_STR_1_1_2
		$goods_info =~ s/$before_rep_str1_1_2/$after_rep_str1/g;
		
		my $before_rep_str1_2_1="<table class=\'infoTable\'><tr><td><table>";
		$goods_info =~ s/$before_rep_str1_2_1/$after_rep_str1/g;
		my $before_rep_str1_2_2=
<<"HTML_STR_1_2_2";
<table class='infoTable'>
<tr>
<td><table>
HTML_STR_1_2_2
		$goods_info =~ s/$before_rep_str1_2_2/$after_rep_str1/g;
		my $after_rep_str2="<td align='center' nowrap='nowrap' scope='col' style='border-bottom:2px solid #CCCCCC;border-right:1px solid #CCCCCC;font-weight:bold;'>";
		my $before_rep_str2_1="<th class=\"col01\">";
		$goods_info =~ s/$before_rep_str2_1/$after_rep_str2/g;
		my $before_rep_str2_2="<th class=\'col01\'>";
		$goods_info =~ s/$before_rep_str2_2/$after_rep_str2/g;		
		my $before_rep_str3="<th>";
		my $after_rep_str3="<td align='center' scope='col' style='border-bottom:2px solid #CCCCCC;border-right:1px solid #CCCCCC;'>";
		$goods_info =~ s/$before_rep_str3/$after_rep_str3/g;
		my $before_rep_str4="</th>";
		my $after_rep_str4="</td>";
		$goods_info =~ s/$before_rep_str4/$after_rep_str4/g;
		my $after_rep_str5="<td align='center' scope='row' style='border-bottom:1px solid #CCCCCC;border-right:1px solid #CCCCCC;font-weight:bold;'>";
		my $before_rep_str5_1="<td class=\"col01\">";
		$goods_info =~ s/$before_rep_str5_1/$after_rep_str5/g;
		my $before_rep_str5_2="<td class=\'col01\'>";
		$goods_info =~ s/$before_rep_str5_2/$after_rep_str5/g;
		my $before_rep_str6="<td>";
		my $after_rep_str6="<td align='center' scope='col' style='border-bottom:1px solid #CCCCCC;border-right:1px solid #CCCCCC;'>";
		$goods_info =~ s/$before_rep_str6/$after_rep_str6/g;
		my $after_rep_str7="</table><div style='margin-top:3px;text-align:right;'><a href='http://www.rakuten.ne.jp/gold/hff/howto-size' target='_blank'>$size_info<img src='http://www.rakuten.ne.jp/gold/hff/image/window.gif'  /></a></div></td></tr></table>";
		my $before_rep_str7_1="</table></td></tr></table>";
		$goods_info =~ s/$before_rep_str7_1/$after_rep_str7/g;
		my $before_rep_str7_2=
<<"HTML_STR_7_2";
</table></td>
</tr>
</table>
HTML_STR_7_2
		$goods_info =~ s/$before_rep_str7_2/$after_rep_str7/g;
		$spec_str="$spec_str$goods_info";
	}


my $html_str6=
<<"HTML_STR_6";

</td>
</tr>
</table>
HTML_STR_6
	# HTML文6を追加
	$spec_str="$spec_str$html_str6";
my $html_str7_0=
<<"HTML_STR_7_0";
<table>
<tr>
<td>[正規販売店証明書]<br />当店はジョンストンズの正規販売店です。</td>
<td><img src="http://image.rakuten.co.jp/hff/cabinet/web/johnstons_authorised.jpg"></td>
</tr>
</table>
HTML_STR_7_0
	Encode::from_to( $html_str7_0, 'utf8', 'shiftjis' );
	my $johnstons_str="ジョンストンズ";
	Encode::from_to( $johnstons_str, 'utf8', 'shiftjis' );
	if(&get_info_from_xml("brand_name") =~ /$johnstons_str/){
		$spec_str .= "$spec_str$html_str7_0";
	}
my $html_str7=
<<"HTML_STR_7";
<br class="clear">
<table width="600" cellpadding="10" cellspacing="1" bgcolor="#eeeeee">
<tr>
<td bgcolor=#FFFFFF>
HTML_STR_7
	# HTML文7を追加
	$spec_str="$spec_str$html_str7";	

my $html_str_whc=
<<"HTML_STR_whc";
・キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋で、ブライドルレザー特有のものです。<br />
・蝋はそのままの状態で発送させていただいております。<br />
・蝋は柔らかい布で拭いたり、ブラッシングすると取れます。<br />
・天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。<br />
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
【ご注文にあたり、必ずお読みください】<br />
●コースは天然素材を使用し、ハンドメイドで作られているため、製造工程上、傷、シミ、汚れ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。これらはすべてKOOSならではの独特の風合いであり、不良品ではございません。<div style="text-align:center;margin:5 auto;"><img src="http://image.rakuten.co.jp/hff/cabinet/web/2k-extra.jpg"></div>
●コースの箱は、輸入の過程で、破損、傷、汚れが生じる場合があります。また箱にマジック等での記載がある場合がございますが、不良品ではございません。<br />
※上記記載事項を理由とする返品・交換は一切お受けできませんので、ご理解いただける方のみご注文ください。<br />
●コースのサイズ感は表記サイズが同じでもデザインによって異なります。<br />
サイズチャートをご確認の上、ご注文ください。<br />
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$spec_str="$spec_str$html_str_whc";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$spec_str="$spec_str$html_str_coos";
	}

my $html_str8=
<<"HTML_STR_8";
・当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。<br />・<a href="http://www.rakuten.ne.jp/gold/hff/howto3.html">商品在庫についてはこちらをご覧ください。</a> </td>
</tr>
</table>
HTML_STR_8
        Encode::from_to( $html_str8, 'utf8', 'shiftjis' );

	# HTML文8を追加
	$spec_str="$spec_str$html_str8";	

	return $spec_str;
}

##############################
## (楽天)モバイル用説明文の生成
##############################
sub create_ry_mb_goods_spec {
	my $mb_goods_spec = "";
	# 商品番号を追加
	my $str_goods_code = "商品番号";
	Encode::from_to( $str_goods_code, 'utf8', 'shiftjis' );
	my $coron="：";
	Encode::from_to( $coron, 'utf8', 'shiftjis' );
	my $slash="／";
	Encode::from_to( $slash, 'utf8', 'shiftjis' );
	$mb_goods_spec .= "$str_goods_code"."$coron"."$global_entry_goods_info[0]"."$slash";
	# カラーを追加
	if ($global_entry_goods_info[5] ne "") {
		my $color_str = "カラー";
		Encode::from_to( $color_str, 'utf8', 'shiftjis' );
		$mb_goods_spec .= "$color_str"."$coron"."$global_entry_goods_info[5]"."$slash";
	}
	# サイズを追加
	my $size_str = "サイズ";
	Encode::from_to( $size_str, 'utf8', 'shiftjis' );	
	if (keys(%global_entry_goods_size_info) != 0) {
		my $size_goods_str="";
		foreach my $size_goods_code (sort keys %global_entry_goods_size_info) {
			my $add_size_str="";
			if ($size_goods_str ne "") {
				$add_size_str=" ";	
			}
			$size_goods_str .= "$add_size_str"."$global_entry_goods_size_info{$size_goods_code}";
		}
		$mb_goods_spec .= "$size_str"."$coron"."$size_goods_str"."$slash";
	}
	# 商品スペックを追加
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		my $spec_info = $specs[$i+1];
		my $before_rep_str_spec1="<br />";
		my $after_rep_str_spec1=" ";
		$spec_info =~ s/$before_rep_str_spec1/$after_rep_str_spec1/g;
		my $before_rep_str_spec2="<br />";
		my $after_rep_str_spec2=" ";
		$spec_info =~ s/$before_rep_str_spec2/$after_rep_str_spec2/g;
		$mb_goods_spec .= "$specs[$i]"."$coron"."$spec_info";
		# 最後以外は／で区切る
		if (($i+2) < $specs_count) {
			$mb_goods_spec .= $slash;
		}
	}
	# メーカーコードの追加処理を削除
=pod	if ($global_entry_goods_info[6] ne "") {
		my $maker_code = "メーカー品番";
		Encode::from_to( $maker_code, 'utf8', 'shiftjis' );
		$mb_goods_spec .= $slash;
		$mb_goods_spec .= "$maker_code".$coron."$global_entry_goods_info[6]";
	}
=cut
	# 最後に<br />タグを2つ追加
#	$mb_goods_spec .= "<br /><br />";
	# 商品コメント2を取得し、コメント修正
	my $goods_info2 = $global_entry_goods_supp_info[1];
	my $before_rep_str3="<table.*>";
	my $after_rep_str3="";
	$goods_info2 =~ s/$before_rep_str3/$after_rep_str3/g;
	my $before_rep_str4="</table>";
	my $after_rep_str4="";
	$goods_info2 =~ s/$before_rep_str4/$after_rep_str4/g;
	my $before_rep_str5_1="<tr >";
	my $after_rep_str5_1="";
	$goods_info2 =~ s/$before_rep_str5_1/$after_rep_str5_1/g;
	my $before_rep_str5_2="<tr>";
	my $after_rep_str5_2="";
	$goods_info2 =~ s/$before_rep_str5_2/$after_rep_str5_2/g;
	my $before_rep_str6="</tr>";
	my $after_rep_str6="";
	$goods_info2 =~ s/$before_rep_str6/$after_rep_str6/g;
	my $before_rep_str7="</td>";
	my $after_rep_str7="";
	$goods_info2 =~ s/$before_rep_str7/$after_rep_str7/g;
	my $before_rep_str8="<td align.*font-weight:bold;'>";
	my $after_rep_str8="<term>";
	$goods_info2 =~ s/$before_rep_str8/$after_rep_str8/g;
	my $before_rep_str9="<td align.*#CCCCCC;'>";
	my $after_rep_str9="";
	$goods_info2 =~ s/$before_rep_str9/$after_rep_str9/g;
	my $before_rep_str10="<div style.*</div>";
	my $after_rep_str10="";
	$goods_info2 =~ s/$before_rep_str10/$after_rep_str10/g;
	# 空白を削除
	$goods_info2 =~ s/ //g;
	# 文字列を配列に格納
	my @goods_info2_array_tmp = split( /\n/, $goods_info2 );
	# 空白行を削除する
	my @goods_info2_array;
	foreach (@goods_info2_array_tmp) {
		if (length($_) != 0) {
			push(@goods_info2_array, $_);
		}
	}	
	# 項目数を算出する
	my $term_num=0;
	foreach (@goods_info2_array) {
		if (index($_ , "<term>") != -1) {
			$term_num++;
		}
	}
	# 各項目内の数を算出する
	my $item_num=0;
	my $item_find=0;
	foreach (@goods_info2_array) {
		if (index($_ , "<term>") != -1) {
			if ($item_find==1) {
				last;
			}
			else {
				$item_find=1;
			}
		}
		else {
			$item_num++;
		}
	}
	# 各項目を文字列に追加する
	for (my $i=0; $i < $item_num; $i++) {
		my $skip=1;
		my $item_count=0;
		my $term_count=0;
		foreach (@goods_info2_array) {
			my $find_str_count=index($_ , "<term>");
			my $find_str_count_2=rindex($_ , ">");
			if ($find_str_count != -1) {
				# 項目名の出力
				my $term_name = substr($_, $find_str_count_2+1);
				chomp($term_name);
				$mb_goods_spec .= "$term_name"."$coron";
				$skip = 0;
				$term_count++;
			}
			elsif($skip != 1) {
				if ($item_count == $i) {
					# スペックを書き込む
					chomp($_);
					$mb_goods_spec .= "$_";
					if ($term_count != $term_num) {
						$mb_goods_spec .= $slash;
					}
					else {
						$mb_goods_spec .= "<br />";
					}
					$skip=1;
					$item_count=0;
				}
				else {
					$item_count++;
				}
			}
		}	
	}
=pod
my $html_str_whc=
<<"HTML_STR_whc";
キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋です。蝋は柔らかい布で拭いたり、ブラッシングすると取れます。天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
※製造工程上、小さな傷、シワ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。不良品ではございません。
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$mb_goods_spec .= "<br />";
		$mb_goods_spec .= "$html_str_whc";
		$mb_goods_spec .= "<br /><br />";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$mb_goods_spec .= "<br />";
		$mb_goods_spec .= "$html_str_coos";
		$mb_goods_spec .= "<br /><br />";
	}
=cut
	# 1024byte制限チェック
	my $len = length $mb_goods_spec;
	if ($len > 1024) {
		# ログファイル出力
		my $warn = "モバイル用商品説明文がサイズ制限(1024byte)を超えています。商品番号：$global_entry_goods_info[0] サイズ：$len(byte)";
		Encode::from_to( $warn, 'utf8', 'shiftjis' );
		&output_log("$warn\n");
	}
	return $mb_goods_spec;
}

##############################
## (楽天)スマートフォン用説明文の生成
##############################
sub create_ry_smp_goods_spec {
	my $smp_goods_spec = "";
	# 商品番号を追加
	my $str_goods_code = "商品番号";
	Encode::from_to( $str_goods_code, 'utf8', 'shiftjis' );
	my $coron="：";
	Encode::from_to( $coron, 'utf8', 'shiftjis' );
	my $paragraph="<br />";
	my $entry_code =$global_entry_goods_info[0];
	$smp_goods_spec .= "$str_goods_code"."$coron"."$entry_code"."$paragraph";
	# カラーを追加
	if ($global_entry_goods_info[5] ne "") {
		my $color_str = "カラー";
		Encode::from_to( $color_str, 'utf8', 'shiftjis' );
		$smp_goods_spec .= "$color_str"."$coron"."$global_entry_goods_info[5]"."$paragraph";
	}
	# サイズを追加
	my $size_str = "サイズ";
	Encode::from_to( $size_str, 'utf8', 'shiftjis' );	
	if (keys(%global_entry_goods_size_info) != 0) {
		my $size_goods_str="";
		foreach my $size_goods_code (sort keys %global_entry_goods_size_info) {
			my $add_size_str="";
			if ($size_goods_str ne "") {
				$add_size_str=" ";	
			}
			$size_goods_str .= "$add_size_str"."$global_entry_goods_size_info{$size_goods_code}";
		}
		$smp_goods_spec .= "$size_str"."$coron"."$size_goods_str"."$paragraph";
	}
	# 商品スペックを追加
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		my $spec_info = $specs[$i+1];
		my $before_rep_str_spec1="<br \/>";
		my $after_rep_str_spec1=" ";
		$spec_info =~ s/$before_rep_str_spec1/$after_rep_str_spec1/g;
		my $before_rep_str_spec2="<br \/>";
		my $after_rep_str_spec2=" ";
		$spec_info =~ s/$before_rep_str_spec2/$after_rep_str_spec2/g;
		$smp_goods_spec .= "$specs[$i]"."$coron"."$spec_info";
		# 最後以外は／で区切る
		if (($i+2) < $specs_count) {
			$smp_goods_spec .= $paragraph;
		}
	}
	$smp_goods_spec .="<br \/><br \/>";
	# 商品コメント1を出力する。
	my $goods_comment_1 = $global_entry_goods_supp_info[0] || "";
	my $before_rep_str0="<ul class=\"link1\">.*<\/ul>";
	my $after_rep_str0="";
	$goods_comment_1 =~ s/$before_rep_str0/$after_rep_str0/g;
	#　消費税増税バナーを削除
	my $after_rep_str1="";
	my $before_rep_str1="<br \/><br \/><p>.*<\/p>";	
	$goods_comment_1 =~ s/$before_rep_str1/$after_rep_str1/g;	
	#　<span class="itemComment">を削除
	my $after_rep_str2="";
	my $before_rep_str2="<span class=\"itemComment\">";
	$goods_comment_1 =~ s/$before_rep_str2/$after_rep_str2/g;
	#　</span>を削除
	my $after_rep_str3="";
	my $before_rep_str3="</span>";
	$goods_comment_1 =~ s/$before_rep_str3/$after_rep_str3/g;
	# フェリージのリンク変換1
	my $after_rep_str4="<a href=\"http://link.rakuten.co.jp/0/048/566/";
	my $before_rep_str4="<a href=\"http://seal.*FCS&f2=glober.jp";
	$goods_comment_1 =~ s/$before_rep_str4/$after_rep_str4/g;
	# フェリージのリンク変換2
	my $after_rep_str5="http://image.rakuten.co.jp/hff/cabinet/pic/felisi/felisi_seal.gif";
	my $before_rep_str5="http://seal.felisi.net/FCSSeal/images/fcs_230x60_json.gif";
	$goods_comment_1 =~ s/$before_rep_str5/$after_rep_str5/g;
	# フォックスのリンク変換
	my $after_rep_str6="http://www.rakuten.ne.jp/gold/hff/brand/foxumbrellas/fx_repair.html";
	my $before_rep_str6="http://blog.glober.jp.*1526#repair";
	$goods_comment_1 =~ s/$before_rep_str6/$after_rep_str6/;
	# ジョンストンズのリンク削除
	my $after_rep_str7="";
	my $before_rep_str7="<br /><br />.*alt=\"johnstons\">";
	$goods_comment_1 =~ s/$before_rep_str7/$after_rep_str7/g;
	# 商品コメント1を追加
	$smp_goods_spec .= $goods_comment_1;
	# 5000円未満の商品は送料無料の注意書きを入れる。
	if ($global_entry_goods_info[3] < 5000){
		my $additional_str = "<br /><br />※5,000円以上のお買い上げで送料無料";
		Encode::from_to( $additional_str, 'utf8', 'shiftjis' );
		$smp_goods_spec .= "$additional_str\n";
	}
my $html_str_whc=
<<"HTML_STR_whc";
<br />キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋です。蝋は柔らかい布で拭いたり、ブラッシングすると取れます。天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
<br />※製造工程上、小さな傷、シワ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。不良品ではございません。
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$smp_goods_spec .= "<br />";
		$smp_goods_spec .= "$html_str_whc";
		$smp_goods_spec .= "<br /><br />";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$smp_goods_spec .= "<br />";
		$smp_goods_spec .= "$html_str_coos";
		$smp_goods_spec .= "<br /><br />";
	}
	#　※※※$smp_goods_specにすべての項目を格納し出力する。※※※
	# 商品コメント2を取得
	my $goods_info_smp = $global_entry_goods_supp_info[1] || "";
	my $before_rep_str8="\\n\\n";
	my $after_rep_str8="\\n";
	$goods_info_smp =~ s/$before_rep_str8/$after_rep_str8/g;
	# <span>タグの削除
	my $before_rep_str8_1="<span>";
	my $after_rep_str8_1="";
	$goods_info_smp =~ s/$before_rep_str8_1/$after_rep_str8_1/g;
	# </span>タグの削除
	my $before_rep_str8_2="</span>";
	my $after_rep_str8_2="";
	$goods_info_smp =~ s/$before_rep_str8_2/$after_rep_str8_2/g;
	# 1行ごとにサイズ要素のみの配列を作る
	my $before_str9="<table class=\"infoTable\"><tr><td><table>";
	my $after_str9="";
	$goods_info_smp =~ s/$before_str9/$after_str9/g;
	# 1行ごとにサイズ要素のみの配列を作る
	my $before_str10="<\/table><\/td><\/tr><\/table>";
	my $after_str10="";	
	$goods_info_smp =~ s/$before_str10/$after_str10/g;
	# サイズチャートがgoods_suppに入力されている場合
	if ($goods_info_smp ne "") {
		# スマホ用サイズチャートのヘッダー
		my $smp_sizechart_header = "<br /><br />【サイズチャート】\n" || "";
		Encode::from_to( $smp_sizechart_header, 'utf8', 'shiftjis' );
		# GLOBERのサイズチャートを改行で分割して配列にする
		my @goods_info_str_list_tr = split(/<tr>/, $goods_info_smp);
		my @goods_info_str_list_sub = split(/<\/th>/, $goods_info_str_list_tr[1]);
		# GLOBERのサイズチャートの行数を格納する
		my $goods_info_str_list_count=@goods_info_str_list_tr;
		# スマホサイズチャートを宣言
		my $smp_sizechart ="$smp_sizechart_header";
		#GLOBERのサイズチャートを<tr>の行ごとに読み込み、1行ずつ処理して変数に追加していく。
		my $i=2;
		# 1行<tr>にあたりにおけるサイズの項目数
		my $size_i=0;
		while ($i <= $goods_info_str_list_count-1){
			# 1行ごとにサイズ要素のみの配列を作る
			my $before_str1="<\/tr>";
			my $after_str1="";	
			$goods_info_str_list_tr[$i] =~ s/$before_str1/$after_str1/g;
			my @goods_info_str_list_size = split(/<\/td><td>/, $goods_info_str_list_tr[$i]);
			# サイズの要素数を格納する
			my $goods_info_str_list_size_count=@goods_info_str_list_size;
			# サイズ要素数が1つのとき
			if ($goods_info_str_list_size_count ==2){
				if ($size_i==0){
					my $before_str_1="<td class=\'col01\'>";
					my $before_str_2="<td class=\"col01\">";
					my $after_str="<br />";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_1/$after_str/g;
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str/g;
					$goods_info_str_list_size[$size_i] = "$goods_info_str_list_size[$size_i]";
					$smp_sizechart .= $goods_info_str_list_size[$size_i];
					$size_i++;
					next;
				}
				else {
					# サイズ項目の余計な文字列を削除
					my $before_str="<th>";
					my $after_str="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str/$after_str/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					my $after_str_1="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					my $after_str_2="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td>";
					my $after_str_3="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/tr>";
					my $after_str_4="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "("."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]".")"."\n";
					$size_i=0;
					$i++;
				}
			}
			# サイズ要素数が2以上のとき
			else{
				# サイズ要素のみの配列を1つずつサイズの要素とサイズ項目を組み合わせてスマホ用サイズチャートを作る
				# 1番目はサイズで余分な文字列を省き、ヘッダーを追加してサイズチャートに格納する
				if ($size_i==0){
					my $before_str_1="<td class=\'col01\'>";
					my $before_str_2="<td class=\"col01\">";
					my $after_str="<br />";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_1/$after_str/g;
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str/g;
					$goods_info_str_list_size[$size_i] = "$goods_info_str_list_size[$size_i]";
					$smp_sizechart .= $goods_info_str_list_size[$size_i];
					$size_i++;
					next;
				}
				# 2番目はサイズ要素のスタートなので、（をつけて1番目のサイズ項目を組み合わせてサイズチャートに格納する
				elsif($size_i==1 ){
					# サイズ項目の余計な文字列を削除
					my $before_str="<th>";
					my $after_str="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str/$after_str/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					my $after_str_1="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					my $after_str_2="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td>";
					my $after_str_3="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/tr>";
					my $after_str_4="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "("."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]";
					$size_i++;
					next;
				}
				elsif($size_i<$goods_info_str_list_size_count-1){
					# サイズ項目の余計な文字列を削除
					my $before_str_0="<th>";
					my $after_str_0="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_0/$after_str_0/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					my $after_str_1="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/tr>";
					my $after_str_2="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td><\/tr>";
					my $after_str_3="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "/"."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]";
					$size_i++;
					next;
				}
				else{
					# サイズ項目の余計な文字列を削除
					my $before_str_0="<th>";
					my $after_str_0="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_0/$after_str_0/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\tr>";
					my $after_str_1="";	
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					my $after_str_2="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/tr>";
					my $after_str_3="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/td>";
					my $after_str_4="";	
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "/"."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]".")"."\n";
					$size_i=0;
					$i++;
				}
			}
		}
		my $before_str_5="\\n"."\)";
		my $after_str_5="";	
		$smp_sizechart =~ s/\n\)/\)/g;
		$smp_goods_spec .=$smp_sizechart;
	}
my $html_str_end=
<<"HTML_STR_end";
<br /><br />・ディスプレイにより、実物と色、イメージが異なる事がございます。あらかじめご了承ください。
<br />・当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。
HTML_STR_end
	Encode::from_to( $html_str_end, 'utf8', 'shiftjis' );
	$smp_goods_spec .=$html_str_end;
	# 5120byte制限チェック
	my $len = length $smp_goods_spec;
	if ($len > 5120) {
		# ログファイル出力
		my $warn = "スマートフォン用商品説明文がサイズ制限(5120byte)を超えています。商品番号：$global_entry_goods_info[0] サイズ：$len(byte)";
		Encode::from_to( $warn, 'utf8', 'shiftjis' );
		&output_log("$warn\n");
	}
	return $smp_goods_spec;
}

##############################
## (楽天)PC用販売説明文の生成
##############################
sub create_r_pc_goods_detail {
my $html_str1=
<<"HTML_STR_1";
<!--タイトルここから -->

<img src="http://www.rakuten.ne.jp/gold/hff/image/spacer.gif" width="600" alt="" height="2" border="0"><br />
<h1>
HTML_STR_1
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
        chomp($html_str1);
my $html_str2=
<<"HTML_STR_2";
</h1>
<img src="http://www.rakuten.ne.jp/gold/hff/image/spacer.gif" width="600" height="20" alt="" border="0">
<img src="http://www.rakuten.ne.jp/gold/hff/image/line_dot_640.jpg" width="600" height="5" alt="" border="0"><br />
<br />
<!--タイトルここまで -->





<!--ブランドプロフィール画像ここから-->
<img src="http://image.rakuten.co.jp/hff/cabinet/bp/
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );
        chomp($html_str2);
my $html_str3=
<<"HTML_STR_3";
.gif" alt="" border="0">
<!--ブランドプロフィール画像 ここまで-->
<br />
<img src="http://www.rakuten.ne.jp/gold/hff/image/spacer.gif" width="600" height="10" alt="" border="0"><br />
<!--商品画像A -->
<center><img src="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_3
        Encode::from_to( $html_str3, 'utf8', 'shiftjis' );
        chomp($html_str3);
my $html_str3_womens=
<<"HTML_STR_3_WOMENS";
.gif" alt="" border="0">
<!--ブランドプロフィール画像 ここまで-->
<br />
<img src="http://www.rakuten.ne.jp/gold/hff/image/spacer.gif" width="600" height="10" alt="" border="0"><br />
<!--商品画像A -->
<center><img src="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_3_WOMENS
        Encode::from_to( $html_str3_womens, 'utf8', 'shiftjis' );
        chomp($html_str3_womens);
        
        my $str_html_str3="";
        # WOMEN'Sの商品は画像格納場所を変える
        if (index($global_entry_goods_info[1], "WOMEN'S", 0) == -1) {
        	# MEN'Sの商品
         	$str_html_str3=$html_str3;
        }
        else {
         	# WOMEN'Sの商品
        	$str_html_str3=$html_str3_womens;
      }      
      
my $html_str4=
<<"HTML_STR_4";
_1.jpg" alt="
HTML_STR_4
        chomp($html_str4);
my $html_str5=
<<"HTML_STR_5";
" border="0"><br />

HTML_STR_5
        chomp($html_str5);
	my $goods_name="$global_entry_goods_info[2] $global_entry_goods_info[5]";
	my $brand_image=&get_info_from_xml("r_image");
	my $pc_goods_detail="$html_str1$global_entry_goods_info[1] $goods_name$html_str2$brand_image$str_html_str3$global_entry_goods_info[0]$html_str4$goods_name$html_str5";
	# 画像数を格納したファイルから各商品の画像数を取得する
	my $image_num=0;
	seek $input_image_num_file_disc,0,0;
	while(my $image_num_line = $input_image_num_csv->getline($input_image_num_file_disc)){
		# 商品コード読み出し
		if ($global_entry_goods_info[0] == @$image_num_line[0]) {
			# 画像の枚数を取得する
			$image_num = @$image_num_line[1];
			last;
		}
	}
# 画像部分の固定文言
my $html_str5_1=
<<"HTML_STR_5_1";
<img src="http://www.rakuten.ne.jp/gold/hff/image/expansion_title.gif" width="600" height="48" alt="" border="0"><br />
<br /></center>
HTML_STR_5_1
        chomp($html_str5_1);

my $html_str6=
<<"HTML_STR_6";
<table width="600" border="0" cellspacing="6" cellpadding="0">
  <tr>
    <td align="center"><a href="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_6
        chomp($html_str6);
my $html_str6_womens=
<<"HTML_STR_6_WOMENS";
<table width="600" border="0" cellspacing="6" cellpadding="0">
  <tr>
    <td align="center"><a href="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_6_WOMENS
        chomp($html_str6_womens);

        
my $html_str7=
<<"HTML_STR_7";
target="_blank"><img src="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_7
        chomp($html_str7);
        
my $html_str7_womens=
<<"HTML_STR_7_WOMENS";
target="_blank"><img src="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_7_WOMENS
        chomp($html_str7_womens);
     
   
my $html_str8=
<<"HTML_STR_8";
alt="
HTML_STR_8
        chomp($html_str8);
my $html_str9=
<<"HTML_STR_9";
" border="0" width="196"></a></td>
HTML_STR_9
        chomp($html_str9);
my $html_str10=
<<"HTML_STR_10";
  </tr>
</table>
HTML_STR_10
        chomp($html_str10);
my $html_str11=
<<"HTML_STR_11";
    <td align="center"><a href="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_11
        chomp($html_str11);
my $html_str11_womens=
<<"HTML_STR_11_WOMENS";
    <td align="center"><a href="http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_11_WOMENS
        chomp($html_str11_womens);

my $html_str12=
<<"HTML_STR_12";
  </tr>
  <tr>
HTML_STR_12
        chomp($html_str12);

	my $str_prefix_temp="";
	my $str_no58_str="";
	my $str_str6_sex="";
	my $str_str7_sex="";
	my $str_str11_sex="";
	for (my $i=2; $i <= $image_num; $i++) {
		# WOMEN'Sの商品だったら画像格納先を変更
		if (index($global_entry_goods_info[1], "WOMEN'S", 0) == -1) {
			# MEN'Sの商品
			$str_str6_sex=$html_str6;
			$str_str7_sex=$html_str7;
			$str_str11_sex=$html_str11;
		}
		else {
			# WOMEN'Sの商品
			$str_str6_sex=$html_str6_womens;
			$str_str7_sex=$html_str7_womens;
			$str_str11_sex=$html_str11_womens;
	        }
	        # 9以上の画像の場合はファイル名を変更
		my $correct_image_name = "";
		my $correct_thumbnail_image_name = "";
		if ($i < 9) {
			$correct_image_name = "$i".".jpg";
			$correct_thumbnail_image_name = "$i"."s.jpg";
		}			
		if ($i >= 9 && $i <= 16) {
			my $correct_cnt=$i%8;
			$correct_image_name = "a\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "a\_$correct_cnt"."s.jpg";	
		}
		elsif ($i >= 17 && $i <= 24) {
			my $correct_cnt=$i%8;
			$correct_image_name = "b\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "b\_$correct_cnt"."s.jpg";
		}
		elsif ($i >= 25 && $i <= 32) {
			my $correct_cnt=$i%8;
			$correct_image_name = "c\_$correct_cnt.jpg";
			$correct_thumbnail_image_name = "c\_$correct_cnt"."s.jpg";
		} 
	        # 画像番号によって振り分け
		if ($i == 2) {
			$str_prefix_temp=$html_str5_1.$str_str6_sex;
		}
		else {
			$str_prefix_temp=$str_str11_sex;
		}
		if (($i>=5) && ($i%3==2)) {
			$str_no58_str=$html_str12;
		}
		else {
			$str_no58_str="";
		}
		
		
		
		$pc_goods_detail="$pc_goods_detail"."$str_no58_str"."$str_prefix_temp"."$global_entry_goods_info[0]"."_"."$correct_image_name"."\" "."$str_str7_sex"."$global_entry_goods_info[0]"."_"."$correct_thumbnail_image_name\" "."$html_str8"."$goods_name"."$html_str9";
	}
	$pc_goods_detail="$pc_goods_detail"."$html_str10";
	return $pc_goods_detail;
}

##############################
## (楽天)商品画像URLの生成
##############################
sub create_r_goods_image_url {
	
my $html_str1=
<<"HTML_STR_1";
http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_1
        chomp($html_str1);
my $html_str1_womens=
<<"HTML_STR_1_WOMENS";
http://image.rakuten.co.jp/hff/cabinet/pic/
HTML_STR_1_WOMENS
        chomp($html_str1_womens);
        
        my $image_url_str="";
	# WOMEN'Sの商品だったら画像格納先を変更
	if (index($global_entry_goods_info[1], "WOMEN'S", 0) == -1) {
		# MEN'Sの商品
		$image_url_str=$html_str1;
	}
	else {
		# WOMEN'Sの商品
		$image_url_str=$html_str1_womens;
	}
        return "$image_url_str"."$global_entry_goods_info[0]"."_1.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_2.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_3.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_4.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_5.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_6.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_7.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_8.jpg"." "."$image_url_str"."$global_entry_goods_info[0]"."_a_1.jpg";
}

##############################
## (楽天)ポイント変倍率
##############################
sub create_r_point {
	# カテゴリ名称からポイント変倍率を取得
	my $brand_point = &get_info_from_xml("brand_point");
	return $brand_point;
}

##############################
## (楽天)ポイント変倍率期間
##############################
sub create_r_point_term {
	# カテゴリ名称からポイント変倍率を取得
	my $brand_point_term = &get_info_from_xml("brand_point_term");
	return $brand_point_term;
}

#########################
###Yahoo用データ作成関数　###
#########################

##############################
## (Yahoo)path情報の生成
##############################
sub create_y_path {
	# ブランド名を取得
	my $path=&get_info_from_xml("y_path");
	# 本店のカテゴリ情報からYahoo店のカテゴリ情報を取得
	# 商品コードの上位5桁を切り出し
	my $entry_goods_code_5=substr($global_entry_goods_info[0], 0, 5);
	seek $input_genre_goods_file_disc,0,0;
	my $genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc);
	while($genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc)){
		my $goods_code_5=@$genre_goods_line[1];
		if (($entry_goods_code_5==$goods_code_5) && (length(@$genre_goods_line[0])==4)) {
			# 表示先カテゴリ
			$path="$path"."\n".&get_y_category_from_xml(@$genre_goods_line[0]);
		}
	}
	return $path;
}

##############################
## (Yahoo)headline の生成
##############################
sub create_y_headline {
	# キャッチコピーデータの作成
	my $headline = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_info[1] eq $str_clober_collection) {
		$headline=&get_info_from_xml("brand_name");
	}
	else {
		$headline=$global_entry_goods_info[1];
	}
=pod #文字数制限にひっかかる為付加しない
	# カテゴリ名を取得し付加する
	foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
		my $y_category_name = &get_y_category_from_xml($global_entry_genre_goods_info{$genre_goods_num});
		if ($y_category_name ne "") {
			$headline .= " "."$y_category_name";
		}
	}
=cut
	# 定型文言
	my $jstr1="【正規販売店】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$headline .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_info[3] >= 5000) {
		my $jstr2="【送料無料】";
		Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
		$headline .= "$jstr2";
	}
	return $headline;
}

##############################
## (Yahoo)商品説明(caption)の生成
##############################
sub create_y_caption {

	# 商品説明文格納用
	my $spec_str="";

my $html_str1=
<<"HTML_STR_1";
<table width='630' border='0' cellspacing='0' cellpadding='0'>
<tr>
<td width='310' valign='top'>
<div style='line-height:120%; color:#333333; padding:0px 10px 6px 0px;'>
HTML_STR_1
	# HTML文1を追加
	$spec_str="$spec_str$html_str1";
	# 商品コメント1を追加
	my $goods_info0 = $global_entry_goods_supp_info[0];
	my $before_rep_str0="<ul class=\"link1\">.*<\/ul>";
	my $after_rep_str0="";
	$goods_info0 =~ s/$before_rep_str0/$after_rep_str0/g;
	#　消費税増税バナーを削除
	my $after_cut_exp="";
	my $before_cut_exp="<br \/><br \/><p>.*<\/p>";
	$goods_info0 =~ s/$before_cut_exp/$after_cut_exp/g;	
	#　<span class="itemComment">を削除
	my $after_rep_str2="";
	my $before_rep_str2="<span class=\"itemComment\">";
	$goods_info0 =~ s/$before_rep_str2/$after_rep_str2/g;
	#　</span>を削除
	my $after_rep_str3="";
	my $before_rep_str3="</span>";
	$goods_info0 =~ s/$before_rep_str3/$after_rep_str3/g;
	# フェリージのリンク変換1
	my $after_rep_str4="<a href=\"http://seal.felisi.net/FCSAuth/index.php?f1=FCS&f2=store.shopping.yahoo.co.jp/hff/";
	my $before_rep_str4="<a href=\"http://seal.*FCS&f2=glober.jp";
	$goods_info0 =~ s/$before_rep_str4/$after_rep_str4/g;
	# フェリージのリンク変換2
	my $after_rep_str5="http://shopping.c.yimg.jp/lib/hff/felisi_seal.gif";
	my $before_rep_str5="http://seal.felisi.net/FCSSeal/images/fcs_230x60_json.gif";
	$goods_info0 =~ s/$before_rep_str5/$after_rep_str5/g;
	# ジョンストンズのリンク削除
	my $after_rep_str6="";
	my $before_rep_str6="<br /><br />[正規販売店証明書].*alt=\"johnstons\">";
	Encode::from_to( $before_rep_str6, 'utf8', 'shiftjis' );
	$goods_info0 =~ s/$before_rep_str6/$after_rep_str6/g;
	# 商品説明を格納
	$spec_str="$spec_str$goods_info0";
	# 商品スペックは一つ目の商品のものを使用
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}

my $html_str2=
<<"HTML_STR_2";
</div></td>
<td width='320' valign='top'><div style='color:#333333; padding:0px; margin-bottom:10px;'>
<table width='320' cellpadding='5' cellspacing='1'>
<tr bgcolor='#eeeeee'>
<td width=80>商品番号</td>
<td>
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );

my $html_str3=
<<"HTML_STR_3";
</td>
</tr>
<tr bgcolor="#eeeeee">
<td>
HTML_STR_3

my $html_str4=
<<"HTML_STR_4";
</td>
<td>
HTML_STR_4

	# 商品番号を追加
	$spec_str .= "$html_str2"."$global_entry_goods_info[0]";
	# カラーを追加
	if ($global_entry_goods_info[5] ne "") {
		my $color_str = "カラー";
		Encode::from_to( $color_str, 'utf8', 'shiftjis' );
		$spec_str .= "$html_str3"."$color_str"."$html_str4"."$global_entry_goods_info[5]";	
	}
	# サイズを追加
	my $size_str = "サイズ";
	Encode::from_to( $size_str, 'utf8', 'shiftjis' );	
	if (keys(%global_entry_goods_size_info) != 0) {
		my $size_goods_str="";
		foreach my $size_goods_code (sort keys %global_entry_goods_size_info) {
			my $add_size_str="";
			if ($size_goods_str ne "") {
				$add_size_str=" ";
			}
			$size_goods_str .= "$add_size_str"."$global_entry_goods_size_info{$size_goods_code}";
		}
		$spec_str .= "$html_str3"."$size_str"."$html_str4"."$size_goods_str";
	}	
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		$spec_str .= "$html_str3"."$specs[$i]"."$html_str4"."$specs[$i+1]";
	}
	# メーカーコードがある場合はスペックの最後に追加
=pod　if ($global_entry_goods_info[6] ne "") {
		my $maker_code = "メーカー品番";
		Encode::from_to( $maker_code, 'utf8', 'shiftjis' );
		$spec_str .= "$html_str3"."$maker_code"."$html_str4"."$global_entry_goods_info[6]";
	}
=cut

my $html_str5=
<<"HTML_STR_5";
</td>
</tr>
</table>
</div>
HTML_STR_5
	# HTML文5(タグ閉じ)を追加
	$spec_str="$spec_str$html_str5";
	# サイズの測り方についての文字列定義
	my $size_info = "サイズの測り方について";
	Encode::from_to( $size_info, 'utf8', 'shiftjis' );	
	my $goods_info = $global_entry_goods_supp_info[1];
	# 商品コメント2が無い場合はサイズの測り方についてのリンクを追加
	if ($goods_info eq "") {
		$spec_str .= "<div style='margin-top:3px;text-align:right;'><a href='howto-size.html' target='_blank'>$size_info<img src='http://lib.shopping.srv.yimg.jp/lib/hff/window.gif' border='0'  /></a></div>";

	}
	else {
		# 商品コメント2を取得し、Yahoo用にコメント修正
		my $goods_info = $global_entry_goods_supp_info[1];
		my $after_rep_str1="<table width='320' border='0' cellpadding='5' cellspacing='0' style='text-align:left; border:1px solid #CCCCCC;border-bottom:none;border-right:none;'>";
		my $before_rep_str1_1_1="<table class=\"infoTable\"><tr><td><table>";
		$goods_info =~ s/$before_rep_str1_1_1/$after_rep_str1/g;
		my $before_rep_str1_1_2=
<<"HTML_STR_1_1_2";
<table class="infoTable">
<tr>
<td><table>
HTML_STR_1_1_2
		$goods_info =~ s/$before_rep_str1_1_2/$after_rep_str1/g;
		my $before_rep_str1_2_1="<table class=\'infoTable\'><tr><td><table>";
		$goods_info =~ s/$before_rep_str1_2_1/$after_rep_str1/g;
		my $before_rep_str1_2_2=
<<"HTML_STR_1_2_2";
<table class='infoTable'>
<tr>
<td><table>
HTML_STR_1_2_2
		$goods_info =~ s/$before_rep_str1_2_2/$after_rep_str1/g;
		my $after_rep_str2="<td align='center' nowrap='nowrap' scope='col' style='border-bottom:2px solid #CCCCCC;border-right:1px solid #CCCCCC;font-weight:bold;'>";
		my $before_rep_str2_1="<th class=\"col01\">";
		$goods_info =~ s/$before_rep_str2_1/$after_rep_str2/g;
		my $before_rep_str2_2="<th class=\'col01\'>";
		$goods_info =~ s/$before_rep_str2_2/$after_rep_str2/g;
		my $before_rep_str3="<th>";
		my $after_rep_str3="<td align='center' scope='col' style='border-bottom:2px solid #CCCCCC;border-right:1px solid #CCCCCC;'>";
		$goods_info =~ s/$before_rep_str3/$after_rep_str3/g;
		my $before_rep_str4="</th>";
		my $after_rep_str4="</td>";
		$goods_info =~ s/$before_rep_str4/$after_rep_str4/g;
		my $after_rep_str5="<td align='center' scope='row' style='border-bottom:1px solid #CCCCCC;border-right:1px solid #CCCCCC;font-weight:bold;'>";
		my $before_rep_str5_1="<td class=\"col01\">";
		$goods_info =~ s/$before_rep_str5_1/$after_rep_str5/g;
		my $before_rep_str5_2="<td class=\'col01\'>";
		$goods_info =~ s/$before_rep_str5_2/$after_rep_str5/g;
		my $before_rep_str6="<td>";
		my $after_rep_str6="<td align='center' scope='col' style='border-bottom:1px solid #CCCCCC;border-right:1px solid #CCCCCC;'>";
		$goods_info =~ s/$before_rep_str6/$after_rep_str6/g;
		my $after_rep_str7="</table><div style='margin-top:3px;text-align:right;'><a href='howto-size.html' target='_blank'>$size_info<img src='http://lib.shopping.srv.yimg.jp/lib/hff/window.gif' border='0'  /></a></div></td></tr></table>";
		my $before_rep_str7_1="</table></td></tr></table>";
		$goods_info =~ s/$before_rep_str7_1/$after_rep_str7/g;
		my $before_rep_str7_2=
<<"HTML_STR_7_2";
</table></td>
</tr>
</table>
HTML_STR_7_2
		$goods_info =~ s/$before_rep_str7_2/$after_rep_str7/g;
		$spec_str .= $goods_info;
	}
my $html_str6=
<<"HTML_STR_6";
</td>
</tr>
</table>
HTML_STR_6
	# HTML文6を追加
	$spec_str="$spec_str$html_str6";

	return $spec_str;
}

##############################
## (Yahoo)explanation情報の生成
##############################
sub create_y_explanation {
	my $explanation=create_ry_mb_goods_spec();
# <br />タグは使用可能？？
=pod
	# <br />, <br />タグを半角スペースに置換
	my $before_rep_str1="<br />";
	my $before_rep_str2="<br />";
	my $after_rep_str=" ";
	$explanation =~ s/$before_rep_str1/$after_rep_str/g;
	$explanation =~ s/$before_rep_str2/$after_rep_str/g;
	# T.B.D <a>タグの削除はどうする？
=cut
	return $explanation;
}

##############################
## (Yahoo)additional1の生成
##############################
sub create_y_additional1 {
	# カテゴリ名
	my $dictionary = &get_info_from_xml("y_dictionary");
	my $additional1 = "$dictionary"."$global_entry_goods_info[1]"." ";
	# 商品名を生成
	$additional1 = "$additional1"."$global_entry_goods_info[2]"." "."$global_entry_goods_info[5]";
my $html_str1=
<<"HTML_STR_1";
</strong></span></td>
</tr>
</table>
HTML_STR_1
	$additional1 = "$additional1"."$html_str1";

	return $additional1;	
}

##############################
## (Yahoo)additional2の生成
##############################
sub create_y_additional2 {
my $html_str1=
<<"HTML_STR_1";
<table width="630" border="0" cellspacing="0" cellpadding="0">
<tr>
<td align="center"><br />
<img src="http://lib7.store.yahoo.co.jp/lib/hff/spacer.gif" height=10 border=0><br />
<!--商品画像A -->
<img src="http://item.shopping.c.yimg.jp/i/f/hff_
HTML_STR_1
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
        chomp($html_str1);
my $html_str2=
<<"HTML_STR_2";
" alt="
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );
        chomp($html_str2);
my $html_str3=
<<"HTML_STR_3";
" border="0"><br /><br />
HTML_STR_3
        chomp($html_str3);
my $html_str4=
<<"HTML_STR_4";
<img src="http://shopping.c.yimg.jp/lib/hff/expansion_title.gif" width="600" height="48" alt="" border="0">
</center><br />
HTML_STR_4
        chomp($html_str4);
       
	my $goods_name="$global_entry_goods_info[2] $global_entry_goods_info[5]";
	my $pc_goods_detail="$html_str1$global_entry_goods_info[0]$html_str2$goods_name$html_str3$html_str4";
	
	# 画像数を格納したファイルから各商品の画像数を取得する
	my $image_num=0;
	seek $input_image_num_file_disc,0,0;
	while(my $image_num_line = $input_image_num_csv->getline($input_image_num_file_disc)){
		# 商品コード読み出し
		if ($global_entry_goods_info[0] == @$image_num_line[0]) {
			# 画像の枚数を取得する
			$image_num = @$image_num_line[1];
			last;
		}
	}
my $html_str5_only_no2=
<<"HTML_STR_5";
<table width="600" border="0" cellspacing="6" cellpadding="0">
  <tr>
    <td align="center"><a href="http://item.shopping.c.yimg.jp/i/f/hff_
HTML_STR_5
        chomp($html_str5_only_no2);
my $html_str6=
<<"HTML_STR_6";
" target="_blank"><img src="http://lib7.store.yahoo.co.jp/lib/hff/
HTML_STR_6
        chomp($html_str6);
my $html_str7=
<<"HTML_STR_7";
alt="
HTML_STR_7
        chomp($html_str7);
my $html_str8=
<<"HTML_STR_8";
" border="0" width="196"></a></td>
HTML_STR_8
        chomp($html_str8);
my $html_str9=
<<"HTML_STR_9";
    <td align="center"><a href="http://item.shopping.c.yimg.jp/i/f/hff_
HTML_STR_9
        chomp($html_str9);
my $html_str10_only_no5_8=
<<"HTML_STR_10";
  </tr>
  <tr>
HTML_STR_10
        chomp($html_str10_only_no5_8);
my $html_str11_only_over6=
<<"HTML_STR_11";
    <td align="center"><a href="http://lib7.store.yahoo.co.jp/lib/hff/
HTML_STR_11
        chomp($html_str11_only_over6);
my $html_str12_only_no678=
<<"HTML_STR_12";
.jpg" target="_blank"><img src="http://lib7.store.yahoo.co.jp/lib/hff/
HTML_STR_12
        chomp($html_str12_only_no678);

	my $str_prefix_temp="";
	my $str_middle_temp="";
	my $str_no5_8_str="";
	for (my $i=2; $i <= $image_num; $i++) {
	        # 9以上の画像の場合はファイル名を変更
		my $correct_image_name = "";
		my $correct_thumbnail_image_name = "";
		if ($i < 9) {
			$correct_image_name = "$i";
			$correct_thumbnail_image_name = "$i"."s.jpg";
		}			
		if ($i >= 9 && $i <= 16) {
			my $correct_cnt=$i%8;
			$correct_image_name = "a\_$correct_cnt";
			$correct_thumbnail_image_name = "a\_$correct_cnt"."s.jpg";	
		}
		elsif ($i >= 17 && $i <= 24) {
			my $correct_cnt=$i%8;
			$correct_image_name = "b\_$correct_cnt";
			$correct_thumbnail_image_name = "b\_$correct_cnt"."s.jpg";
		}
		elsif ($i >= 25 && $i <= 32) {
			my $correct_cnt=$i%8;
			$correct_image_name = "c\_$correct_cnt";
			$correct_thumbnail_image_name = "c\_$correct_cnt"."s.jpg";
		} 
		# 画像登録HTML
		if ($i==2) {
			$str_prefix_temp=$html_str5_only_no2;
			$str_middle_temp=$html_str6;
			$str_no5_8_str="";
		}
		elsif ($i==3 || $i==4) {
			$str_prefix_temp=$html_str9;
			$str_middle_temp=$html_str6;
			$str_no5_8_str="";
		}			
		elsif ($i==5) {
			$str_prefix_temp=$html_str9;
			$str_middle_temp=$html_str6;
			$str_no5_8_str=$html_str10_only_no5_8;
		}
		else {
			$str_prefix_temp=$html_str11_only_over6;
			$str_middle_temp=$html_str12_only_no678;
			if ($i%3==2) {
				$str_no5_8_str=$html_str10_only_no5_8;
			}
			else {
				$str_no5_8_str="";
			}
		}
		$pc_goods_detail="$pc_goods_detail"."$str_no5_8_str"."$str_prefix_temp"."$global_entry_goods_info[0]"."_"."$correct_image_name"."$str_middle_temp"."$global_entry_goods_info[0]"."_"."$correct_image_name"."s.jpg\" "."$html_str7"."$goods_name"."$html_str8";
	}
my $html_str11=
<<"HTML_STR_11";
  </tr>
</table>
</td>
</tr>
</table>
HTML_STR_11
        chomp($html_str11);
	$pc_goods_detail="$pc_goods_detail"."$html_str11";
	return $pc_goods_detail;
}

##############################
## (Yahoo)additional3の生成
##############################
sub create_y_additional3 {
	my $additional3_str ="";
my $html_str_0=
<<"HTML_STR_0";
<table>
<tr>
<td>[正規販売店証明書]<br />当店はジョンストンズの正規販売店です。</td>
<td><img src="http://shopping.c.yimg.jp/lib/hff/johnstons_authorised.jpg"></td>
</tr>
<table>
HTML_STR_0
	Encode::from_to( $html_str_0, 'utf8', 'shiftjis' );
	my $johnstons_str="ジョンストンズ";
	Encode::from_to( $johnstons_str, 'utf8', 'shiftjis' );
	if(&get_info_from_xml("brand_name") =~ /$johnstons_str/){
		$additional3_str = "$html_str_0";
	}
my $html_str1=
<<"HTML_STR_1";
<table width='630' border='0' cellspacing='0' cellpadding='8' style='border:1px solid #CCCCCC;'>
<tr>
<td><font style='font-size:small;color:#333333;line-height:120%;'>
HTML_STR_1
        $additional3_str .= "$html_str1";
        
my $html_str_whc=
<<"HTML_STR_whc";
・キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋で、ブライドルレザー特有のものです。<br />
・蝋はそのままの状態で発送させていただいております。<br />
・蝋は柔らかい布で拭いたり、ブラッシングすると取れます。<br />
・天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。<br />
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
【ご注文にあたり、必ずお読みください】<br />
●コースは天然素材を使用し、ハンドメイドで作られているため、製造工程上、傷、シミ、汚れ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。これらはすべてKOOSならではの独特の風合いであり、不良品ではございません。<div style="text-align:center;margin:5 auto;"><img src="http://image.rakuten.co.jp/hff/cabinet/web/2k-extra.jpg"></div>
●コースの箱は、輸入の過程で、破損、傷、汚れが生じる場合があります。また箱にマジック等での記載がある場合がございますが、不良品ではございません。<br />
※上記記載事項を理由とする返品・交換は一切お受けできませんので、ご理解いただける方のみご注文ください。<br />
●コースのサイズ感は表記サイズが同じでもデザインによって異なります。<br />
サイズチャートをご確認の上、ご注文ください。<br />
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$additional3_str="$additional3_str$html_str_whc";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$additional3_str="$additional3_str$html_str_coos";
	}

my $html_str2=
<<"HTML_STR_2";
・ディスプレイにより、実物と色、イメージが異なる事がございます。あらかじめご了承ください。<br />
・当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。<br />
・<a href='howto3.html' target='_blank'>商品在庫についてはこちらをご覧ください。</a><br />・<a href='inforepair.html' target='_blank'>お直しについてはこちらをご覧ください。</a></font></td>
</tr>
</table>
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );

	$additional3_str = "$additional3_str"."$html_str2";
	return $additional3_str;	
}

##############################
## (Yahoo)create_y_subcodeの生成
##############################
sub create_y_subcode {
	# SKUの場合のみ登録
	my $subcode="";
	if (length($global_entry_goods_info[0])==7) {
		# 定型文言
		my $size_str="サイズ:";
		Encode::from_to( $size_str, 'utf8', 'shiftjis' );	
		# サイズを取得
		foreach my $goods_code_tmp ( sort keys %global_entry_goods_size_info ) {
			chomp $global_entry_goods_size_info{$goods_code_tmp};
			if($subcode ne "") {
				$subcode="$subcode"."&";
			}
			$subcode = "$subcode"."$size_str"."$global_entry_goods_size_info{$goods_code_tmp}"."="."$goods_code_tmp";
		}
	}
	return $subcode;
}

##############################
## (Yahoo)create_y_optionsの生成
##############################
sub create_y_options {
	my $options="";
	# ※あすつく文言の登録不要となったので空で入力
	my $tomorrow_hope_str="";
	Encode::from_to( $tomorrow_hope_str, 'utf8', 'shiftjis' );	
	# SKUの場合のみ登録
	if (length($global_entry_goods_info[0])==7) {
		# 定型文言
		# サイズを取得
		foreach my $goods_code_tmp ( sort keys %global_entry_goods_size_info ) {
			chomp $global_entry_goods_size_info{$goods_code_tmp};
			if($options eq "") {
				$options = $tomorrow_hope_str;
my $size_str=
<<"HTML_STR";


サイズ 
HTML_STR
		Encode::from_to( $size_str, 'utf8', 'shiftjis' );
		chomp $size_str;
				$options .= "$size_str";
			}
			else {
				$options .= " ";
			}
			$options .= "$global_entry_goods_size_info{$goods_code_tmp}";
		}
	}
	else {
		$options = $tomorrow_hope_str;
	}
	return $options;
}

##############################
## (Yahoo)relevant-linksの生成
##############################
sub create_y_relevant_links {
	# 登録する商品の次の商品番号を5つ登録する
	my $relevant_links_str="";
	my $item_list_num=@global_item_list;
	my $item_list_count=0;
	for (my $i=0; $i<$item_list_num; $i++) {
		my $item_line = $global_item_list[$i];
		# 登録情報から商品コード読み出し
		my @item_line_split=split(/,/, $item_line);
		my $goods_code=$item_line_split[0];
		if ($global_entry_goods_info[0] eq $goods_code) {
			my $relevant_num=0;
			my $relevant_num_max=0;
			if ($item_list_num > 5) {
				$relevant_num_max=6;
			}
			else {
				$relevant_num_max=$item_list_num;
			}
			for (my $y=1; $y<$relevant_num_max; $y++) {
				if (($i+$y) >= $item_list_num) {
					$relevant_num=($i+$y)-$item_list_num;
				}
				else {
					$relevant_num=$i+$y;
				}
				my $item_line_temp = $global_item_list[$relevant_num];
				my @relevant_split=split(/,/, $item_line_temp);
				my $entry_goods_code=$relevant_split[0];
				if ($relevant_links_str ne "") {
					$relevant_links_str="$relevant_links_str"." ";
				}
				$relevant_links_str="$relevant_links_str"."$entry_goods_code";
			}
		}
	}
	return $relevant_links_str;
}

#####################
### ユーティリティ関数　###
#####################
## 指定されたカテゴリ名に対応するカテゴリをXMLファイルから取得する
sub get_info_from_xml {
	my $info_name = $_[0]; 
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$brand_xml_filename",ForceArray=>['brand']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_name = $xml_data->{brand}[$count]->{category_name};
		if (!$xml_category_name) {
			# 全て読み出したら終了
			last;
		}
		Encode::_utf8_off($xml_category_name);
		Encode::from_to( $xml_category_name, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($global_entry_goods_info[1] eq $xml_category_name){
			$info = $xml_data->{brand}[$count]->{$info_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	return $info;
}

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

## 指定されたスサイズに対応するサイズタグ情報をXMLファイルから取得する
sub get_r_sizetag_from_xml {
	my $category_num = $_[0]; 
	my $size = $_[1]; 
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$r_size_tag_xml_filename",ForceArray=>['category_size']);
	# XMLからカテゴリを取得
	my $category_size_count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ番号を取得
		my $xml_g_category_num = $xml_data->{category_size}[$category_size_count]->{g_category_num};
		if (!$xml_g_category_num) {
			# 情報を取得できなかったので終了
			last;
		}
		Encode::_utf8_off($xml_g_category_num);
		Encode::from_to( $xml_g_category_num, 'utf8', 'shiftjis' );
		my $xml_g_size = $xml_data->{category_size}[$category_size_count]->{g_size};
		Encode::_utf8_off($xml_g_size);
		Encode::from_to( $xml_g_size, 'utf8', 'shiftjis' );
		my $is_end=0;
		if (($xml_g_category_num eq $category_num) && ($xml_g_size eq $size)) {
			# カテゴリ番号とサイズが合致した場合はサイズタグを取得する
			$info=$xml_data->{category_size}[$category_size_count]->{r_size_tag};
			if (!$info) {
				# 情報を取得できなかった
				output_log("not exist r_size_tag(category_num:$category_num  size:$size) in $r_size_tag_xml_filename\n");
			}
			# 曖昧なサイズだったらその旨ログに出力する
			if ($xml_data->{category_size}[$category_size_count]->{confusion}) {
				output_log("Rakuten sizetag confusion!! [$global_entry_goods_info[0]] size:$size\n");
			}
			last;
		}
		$category_size_count++;
	}
	return $info;
}

## 指定されたGLOBERのカテゴリ番号に対応する楽天のカテゴリ名をXMLファイルから取得する
## arg1=GLOBERのカテゴリ番号　　arg2=商品ページに表示する文言取得は0, カテゴリ名取得は1
sub get_r_category_from_xml {
	my $category_number = $_[0];
	my $category_disp_type = $_[1];
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
		if (!$xml_category_number) {
			# 情報を取得できなかったので、終了
			output_log("not exist xml_category_number($xml_category_number) in $category_xml_filename\n");
			last;
		}
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number == $xml_category_number){
			$info = $xml_data->{category}[$count]->{r_category_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	if ($category_disp_type == 1) {
		# カテゴリ名取得の場合は'\'の後ろのカテゴリ名のみにする
		$info = substr($info, index($info, "\\")+1);
	}
	return $info;
}

## 指定されたGLOBERのカテゴリ番号に対応するYahooのカテゴリ名をXMLファイルから取得する
sub get_y_category_from_xml {
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
		if (!$xml_category_number) {
			# 情報を取得できなかったので、終了
			output_log("not exist xml_category_number($xml_category_number) in $category_xml_filename\n");
			last;
		}
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number == $xml_category_number){
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
	my $day=&to_YYYYMMDD_string();
	print "[$day]:$_[0]";
	print LOG_FILE "[$day]:$_[0]";
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}
