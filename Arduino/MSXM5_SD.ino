//2024. 3.13 sd-card再挿入時の初期化処理を追加
//2024. 6.10 m5用処理（PC-8001ベース）を追加
//
#include "SdFat.h"
#include <SPI.h>
SdFat SD;
unsigned long r_count=0;
unsigned long f_length=0, w_length=0;
char m_name[40];
char f_name[40];
char w_name[40];
char c_name[40];
char sdir[10][40];
File file_r,file_w;
unsigned int s_adrs,e_adrs,g_adrs,s_adrs1,s_adrs2;
int s_len1,s_len2,w_len1,w_len2;
boolean eflg;

#define CABLESELECTPIN  (10)
#define CHKPIN          (15)
#define PB0PIN          (2)
#define PB1PIN          (3)
#define PB2PIN          (4)
#define PB3PIN          (5)
#define PB4PIN          (6)
#define PB5PIN          (7)
#define PB6PIN          (8)
#define PB7PIN          (9)
#define FLGPIN          (14)
#define PA0PIN          (16)
#define PA1PIN          (17)
#define PA2PIN          (18)
#define PA3PIN          (19)
// ファイル名は、ロングファイルネーム形式対応

void sdinit(void){
  // SD初期化
  if( !SD.begin(CABLESELECTPIN,8) )
  {
////    Serial.println("Failed : SD.begin");
    eflg = true;
  } else {
////    Serial.println("OK : SD.begin");
    eflg = false;
  }
////    Serial.println("START");
}

void setup(){
////    Serial.begin(9600);
// CS=pin10
// pin10 output

  pinMode(CABLESELECTPIN,OUTPUT);
  pinMode( CHKPIN,INPUT);  //CHK
  pinMode( PB0PIN,OUTPUT); //送信データ
  pinMode( PB1PIN,OUTPUT); //送信データ
  pinMode( PB2PIN,OUTPUT); //送信データ
  pinMode( PB3PIN,OUTPUT); //送信データ
  pinMode( PB4PIN,OUTPUT); //送信データ
  pinMode( PB5PIN,OUTPUT); //送信データ
  pinMode( PB6PIN,OUTPUT); //送信データ
  pinMode( PB7PIN,OUTPUT); //送信データ
  pinMode( FLGPIN,OUTPUT); //FLG

  pinMode( PA0PIN,INPUT_PULLUP); //受信データ
  pinMode( PA1PIN,INPUT_PULLUP); //受信データ
  pinMode( PA2PIN,INPUT_PULLUP); //受信データ
  pinMode( PA3PIN,INPUT_PULLUP); //受信データ

  digitalWrite(PB0PIN,LOW);
  digitalWrite(PB1PIN,LOW);
  digitalWrite(PB2PIN,LOW);
  digitalWrite(PB3PIN,LOW);
  digitalWrite(PB4PIN,LOW);
  digitalWrite(PB5PIN,LOW);
  digitalWrite(PB6PIN,LOW);
  digitalWrite(PB7PIN,LOW);
  digitalWrite(FLGPIN,LOW);

  delay(500);

//SETSコマンドでSAVE用ファイル名を指定なくSAVEされた場合のデフォルトファイル名を設定
  strcpy(w_name,"default.cas");

  sdinit();
}

//4BIT受信
byte rcv4bit(void){
//HIGHになるまでループ
  while(digitalRead(CHKPIN) != HIGH){
  }
//受信
  byte j_data = digitalRead(PA0PIN)+digitalRead(PA1PIN)*2+digitalRead(PA2PIN)*4+digitalRead(PA3PIN)*8;
//FLGをセット
  digitalWrite(FLGPIN,HIGH);
//LOWになるまでループ
  while(digitalRead(CHKPIN) == HIGH){
  }
//FLGをリセット
  digitalWrite(FLGPIN,LOW);
  return(j_data);
}

//1BYTE受信
byte rcv1byte(void){
  byte i_data = 0;
  i_data=rcv4bit()*16;
  i_data=i_data+rcv4bit();
  return(i_data);
}

//1BYTE送信
void snd1byte(byte i_data){
//下位ビットから8ビット分をセット
  digitalWrite(PB0PIN,(i_data)&0x01);
  digitalWrite(PB1PIN,(i_data>>1)&0x01);
  digitalWrite(PB2PIN,(i_data>>2)&0x01);
  digitalWrite(PB3PIN,(i_data>>3)&0x01);
  digitalWrite(PB4PIN,(i_data>>4)&0x01);
  digitalWrite(PB5PIN,(i_data>>5)&0x01);
  digitalWrite(PB6PIN,(i_data>>6)&0x01);
  digitalWrite(PB7PIN,(i_data>>7)&0x01);
  digitalWrite(FLGPIN,HIGH);
//HIGHになるまでループ
  while(digitalRead(CHKPIN) != HIGH){
  }
  digitalWrite(FLGPIN,LOW);
//LOWになるまでループ
  while(digitalRead(CHKPIN) == HIGH){
  }
}

//小文字->大文字
char upper(char c){
  if('a' <= c && c <= 'z'){
    c = c - ('a' - 'A');
  }
  return c;
}

//ファイル名の最後が「.cas」でなければ付加
void addcas(char *f_name,char *m_name){
  unsigned int lp1=0;
  while (f_name[lp1] != 0x00){
    m_name[lp1] = f_name[lp1];
    lp1++;
  }
  if (f_name[lp1-4]!='.' ||
    ( f_name[lp1-3]!='c' &&
      f_name[lp1-3]!='C' ) ||
    ( f_name[lp1-2]!='a'  &&
      f_name[lp1-3]!='A' ) ||
    ( f_name[lp1-1]!='s' &&
      f_name[lp1-1]!='S' ) ){
         m_name[lp1++] = '.';
         m_name[lp1++] = 'c';
         m_name[lp1++] = 'a';
         m_name[lp1++] = 's';
  }
  m_name[lp1] = 0x00;
}

//比較文字列取得 32+1文字まで取得、ただしダブルコーテーションは無視する
void receive_name(char *f_name){
char r_data;
  unsigned int lp2 = 0;
  for (unsigned int lp1 = 0;lp1 <= 32;lp1++){
    r_data = rcv1byte();
    if (r_data != 0x22){
      f_name[lp2] = r_data;
      lp2++;
    }
  }
}

//比較文字列取得 32+1文字まで取得し先頭の6文字をファイルネームとする、ただしダブルコーテーションは無視する
void receive_name6(char *f_name){
char r_data;
  unsigned int lp2 = 0;
  for (unsigned int lp1 = 0;lp1 <= 32;lp1++){
    r_data = rcv1byte();
    if (lp2 < 6){
      if (r_data != 0x22){
        f_name[lp2] = r_data;
        lp2++;
      }
    }else{
      f_name[lp2] = 0x00;
      lp2++;
    }
  }
}

//f_nameとc_nameをc_nameに0x00が出るまで比較
//FILENAME COMPARE
boolean f_match(char *f_name,char *c_name){
  boolean flg1 = true;
  unsigned int lp1 = 0;
  while (lp1 <=32 && c_name[0] != 0x00 && flg1 == true){
    if (upper(f_name[lp1]) != c_name[lp1]){
      flg1 = false;
    }
    lp1++;
    if (c_name[lp1]==0x00){
      break;
    }
  }
  return flg1;
}

// SD-CARDのFILELIST
void dirlist(void){
//比較文字列取得 32+1文字まで
  receive_name(c_name);
//
  File file2 = SD.open( "/" );
  if( file2 == true ){
//状態コード送信(OK)
    snd1byte(0x00);

    File entry =  file2.openNextFile();
    int cntl2 = 0;
    unsigned int br_chk =0;
    int page = 1;
//全件出力の場合には10件出力したところで一時停止、キー入力により継続、打ち切りを選択
    while (br_chk == 0) {
      if(entry){
        entry.getName(f_name,36);
        unsigned int lp1=0;
//一件送信
//比較文字列でファイルネームを先頭から比較して一致するものだけを出力
        if (f_match(f_name,c_name)){
//sdir[]にf_nameを保存
          strcpy(sdir[cntl2],f_name);
          snd1byte(0x30+cntl2);
          snd1byte(0x20);
          while (lp1<=36 && f_name[lp1]!=0x00){
          snd1byte(upper(f_name[lp1]));
          lp1++;
          }
          snd1byte(0x0D);
          snd1byte(0x00);
          cntl2++;
        }
      }
// CNTL2 > 表示件数-1
      if (!entry || cntl2 > 9){
//継続・打ち切り選択指示要求
        snd1byte(0xfe);

//選択指示受信(0:継続 B:前ページ 以外:打ち切り)
        br_chk = rcv1byte();
//前ページ処理
        if (br_chk==0x42){
//先頭ファイルへ
          file2.rewindDirectory();
//entry値更新
          entry =  file2.openNextFile();
//もう一度先頭ファイルへ
          file2.rewindDirectory();
          if(page <= 2){
//現在ページが1ページ又は2ページなら1ページ目に戻る処理
            page = 0;
          } else {
//現在ページが3ページ以降なら前々ページまでのファイルを読み飛ばす
            page = page -2;
            cntl2=0;
//page*表示件数
            while(cntl2 < page*10){
              entry =  file2.openNextFile();
              if (f_match(f_name,c_name)){
                cntl2++;
              }
            }
          }
          br_chk=0;
        }
//1～0までの数字キーが押されたらsdir[]から該当するファイル名を送信
        if(br_chk>=0x30 && br_chk<=0x39){
          file_r = SD.open( sdir[br_chk-0x30], FILE_READ );
          if( file_r == true ){
//f_length設定、r_count初期化
            f_length = file_r.size();
            r_count = 0;
            unsigned int lp2=0;
            snd1byte(0xFD);
            while (lp2<=36 && sdir[br_chk-0x30][lp2]!=0x00){
              snd1byte(upper(sdir[br_chk-0x30][lp2]));
              lp2++;
            }
            snd1byte(0x0A);
            snd1byte(0x0D);
            snd1byte(0x00);
          }
        }
        page++;
        cntl2 = 0;
      }
//ファイルがまだあるなら次読み込み、なければ打ち切り指示
      if (entry){
        entry =  file2.openNextFile();
      }else{
        br_chk=1;
      }
    }
//処理終了指示
    snd1byte(0xFF);
    snd1byte(0x00);
  }else{
    snd1byte(0xf1);
  }
}

// LOADFILEOPEN 読み込み用のファイル名を設定する
void loadopen(void){
  boolean flg = false;
//DOSファイル名取得
  receive_name(m_name);
  addcas(m_name,f_name);
//ファイルが存在しなければERROR
  if (SD.exists(f_name) == true){
//ファイルオープン
    file_r = SD.open( f_name, FILE_READ );

    if( true == file_r ){
//f_length設定、r_count初期化
      f_length = file_r.size();
      r_count = 0;
//状態コード送信(OK)
      snd1byte(0x00);
      flg = true;
    } else {
      snd1byte(0xf2);
      sdinit();
      flg = false;
    }
  }else{
    snd1byte(0xf1);
    sdinit();
    flg = false;
  }
}

// SAVEFILEOPEN 書き込み用のファイル名を設定する
void saveopen(void){
  boolean flg = false;
//DOSファイル名取得
  receive_name(m_name);
  addcas(m_name,f_name);
  strcpy(w_name,f_name);
//ファイルオープン
  if(file_w==true){
    file_w.close();
  }
  file_w = SD.open( w_name, FILE_WRITE );
//状態コード送信(OK)
  snd1byte(0x00);
}

// sloadコマンド
void sload(void){
  boolean flg = false;
  int wk1 =0;
  unsigned char rdata;
  unsigned int lp1 =0;
//比較文字列取得 32+1文字まで
  receive_name6(c_name);
  if (file_r == true){
    snd1byte(0x00);
//0xd3が10個連続するまで読み飛ばし、読み飛ばしでファイルエンドになってしまったらエラー終了
    while (flg == false && f_length >= r_count){
      rdata=file_r.read();
      r_count++;
      if (rdata == 0xd3){
          wk1++;
        } else{
          wk1=0;
      }
      if (wk1 >= 10 ){
        flg = true;
      }
//ファイルネームが指定された場合、読み出したファイルネームが一致するまで読み飛ばし
      if (flg == true){
        for(lp1=0; lp1 <= 5;lp1++){
          f_name[lp1]=file_r.read();
          r_count++;
        }
        f_name[6]=0x00;
        if (c_name[0]!=0x00){
          if (f_match(f_name,c_name) == false){
            flg = false;
          }
        }
      }
    }
    if(flg == true){
      snd1byte(0x00);
//ファイルネームを送信
      for(lp1=0; lp1 <= 5;lp1++){
        snd1byte(f_name[lp1]);
      }
//ヘッダを読み飛ばし
      for(lp1=1; lp1 <= 8;lp1++){
        rdata=file_r.read();
        r_count++;
      }
//次行アドレスポインタから1行Byte数を計算し送信、1行Byte数分の実データも読み出して送信
      s_adrs2=file_r.read();
      r_count++;
      s_adrs1=file_r.read();
      r_count++;
      e_adrs = s_adrs1*256+s_adrs2;
      if (e_adrs != 0){
        wk1=s_adrs2-3;
        snd1byte(wk1);
        s_adrs =e_adrs;
        for (lp1=1;lp1 <= wk1;lp1++){
          rdata=file_r.read();
          r_count++;
          snd1byte(rdata);
        }
      }
//2行目以降処理
//次行アドレスポインタから1行Byte数を計算し送信、1行Byte数分の実データも読み出して送信
      while (e_adrs != 0){
        s_adrs2=file_r.read();
        r_count++;
        s_adrs1=file_r.read();
        r_count++;
        e_adrs = s_adrs1*256+s_adrs2;
        if (e_adrs != 0){
          wk1 = e_adrs-s_adrs-2;
          s_adrs =e_adrs;
          snd1byte(wk1);
          for (lp1=1;lp1 <= wk1;lp1++){
            rdata=file_r.read();
            r_count++;
            snd1byte(rdata);
          }
        }
      }
      snd1byte(0x00);
    } else{
      snd1byte(0xf1);
      sdinit();
      r_count = 0;
    }
  } else{
    snd1byte(0xf1);
    sdinit();
    r_count = 0;
  }
}

// sbloadコマンド
void sbload(void){
  boolean flg = false;
  int wk1 =0;
  unsigned char rdata;
  unsigned int lp1 =0;
//比較文字列取得 32+1文字まで
  receive_name6(c_name);
  if (file_r == true){
    snd1byte(0x00);
//0xd0を10個連続するまで読み飛ばし、読み飛ばしでファイルエンドになってしまったらエラー終了
    while (flg == false && f_length >= r_count){
      rdata=file_r.read();
      r_count++;
      if (rdata == 0xd0){
          wk1++;
        } else{
          wk1=0;
      }
      if (wk1 >= 10 ){
        flg = true;
      }
//ファイルネームが指定された場合、読み出したファイルネームが一致するまで読み飛ばし
      if (flg == true){
        for(lp1=0; lp1 <= 5;lp1++){
          f_name[lp1]=file_r.read();
          r_count++;
        }
        f_name[6]=0x00;
        if (c_name[0]!=0x00){
          if (f_match(f_name,c_name) == false){
            flg = false;
          }
        }
      }
    }
    if(flg == true){
      snd1byte(0x00);
//ファイルネームを送信
      for(lp1=0; lp1 <= 5;lp1++){
        snd1byte(f_name[lp1]);
      }
//ヘッダを読み飛ばし
      for(lp1=1; lp1 <= 8;lp1++){
        rdata=file_r.read();
        r_count++;
      }
//スタートアドレスを読み出して送信
      s_adrs2=file_r.read();
      r_count++;
      s_adrs1=file_r.read();
      r_count++;
      s_adrs = s_adrs1*256+s_adrs2;
      snd1byte(s_adrs2);
      snd1byte(s_adrs1);
//エンドアドレスを読み出して送信
      s_adrs2=file_r.read();
      r_count++;
      s_adrs1=file_r.read();
      r_count++;
      e_adrs = s_adrs1*256+s_adrs2;
      snd1byte(s_adrs2);
      snd1byte(s_adrs1);
//実行アドレスを読み出して送信
      s_adrs2=file_r.read();
      r_count++;
      s_adrs1=file_r.read();
      r_count++;
      g_adrs = s_adrs1*256+s_adrs2;
      snd1byte(s_adrs2);
      snd1byte(s_adrs1);
//スタートアドレスからエンドアドレスまでのデータを読み出して送信
      for(lp1=s_adrs; lp1 <= e_adrs;lp1++){
        rdata=file_r.read();
        snd1byte(rdata);
        r_count++;
      }
    } else{
      snd1byte(0xf1);
      sdinit();
      r_count = 0;
    }
  } else{
    snd1byte(0xf1);
    sdinit();
    r_count = 0;
  }
}

//ヘッダ書き込み
void header_write(void){
        file_w.write(char(0x1f));
        file_w.write(char(0xa6));
        file_w.write(char(0xde));
        file_w.write(char(0xba));
        file_w.write(char(0xcc));
        file_w.write(char(0x13));
        file_w.write(char(0x7d));
        file_w.write(char(0x74));
}

//ファイルヘッダ書き込み
void file_header(char hdata){
  unsigned int lp1 =0;
//ロングヘッダ書き込み
  header_write();
//hdata x 10
  for(lp1=1; lp1 <= 10;lp1++){
    file_w.write(hdata);
  }
//ファイルネーム送信及び書き込み
  for(lp1=0; lp1 <= 5;lp1++){
    snd1byte(c_name[lp1]);
    file_w.write(c_name[lp1]);
  }
//ショートヘッダ書き込み
      header_write();
}

// ssaveコマンド
void ssave(void){
  boolean flg = false;
  unsigned int wk1 =0;
  unsigned char rdata;
  unsigned int lp1 =0;
//比較文字列取得 32+1文字まで
  receive_name6(c_name);
//ファイルネームが指定されていなければエラー
  if (c_name[0] != 0x00){
//w_nameでファイルオープン
    if(file_w==true){
      file_w.close();
    }
    file_w = SD.open( w_name, FILE_WRITE );
    if(file_w==true){
      snd1byte(0x00);
//ファイルヘッダ書き込み
      file_header(char(0xd3));
      wk1=rcv1byte();
//1行Byte数が0になるまでループ
      while(wk1!=0){
//次行プログラムポインタを受信して書き込み
        rdata=rcv1byte();
        file_w.write(rdata);
        rdata=rcv1byte();
        file_w.write(rdata);
//1行分のデータを受信して書き込み
          for(lp1=1; lp1 <= wk1;lp1++){
            rdata=rcv1byte();
            file_w.write(rdata);
          }
        wk1=rcv1byte();
      }
//終了マークを書き込み
      for(lp1=1; lp1 <= 12;lp1++){
        file_w.write(char(0x00));
      }
      file_w.close();
      snd1byte(0x00);
    }else{
      snd1byte(0xf1);
      sdinit();
    }
  }else{
    snd1byte(0xf1);
    sdinit();
  }
}  

// sbsaveコマンド
void sbsave(void){
  boolean flg = false;
  unsigned int wk1 =0;
  unsigned char rdata;
  unsigned int lp1 =0;
//比較文字列取得 32+1文字まで
  receive_name6(c_name);
//パラメータ正常フラグが送られてきたら処理継続
  rdata = rcv1byte();
  if (rdata == 0x00){
//ファイルネームが指定されていなければエラー終了
    if (c_name[0] != 0x00){
//w_nameでファイルオープン
      if(file_w==true){
        file_w.close();
      }
      file_w = SD.open( w_name, FILE_WRITE );
      if(file_w==true){
        snd1byte(0x00);
//ファイルヘッダ書き込み
      file_header(char(0xd0));
//スタートアドレス受信及び書き込み
        s_adrs1=rcv1byte();
        file_w.write(s_adrs1);
        s_adrs2=rcv1byte();
        file_w.write(s_adrs2);
        s_adrs = s_adrs2*256+s_adrs1;
//エンドアドレス受信及び書き込み
        s_adrs1=rcv1byte();
        file_w.write(s_adrs1);
        s_adrs2=rcv1byte();
        file_w.write(s_adrs2);
        e_adrs = s_adrs2*256+s_adrs1;
//実行アドレス受信及び書き込み
        s_adrs1=rcv1byte();
        file_w.write(s_adrs1);
        s_adrs2=rcv1byte();
        file_w.write(s_adrs2);
        g_adrs = s_adrs2*256+s_adrs1;
//スタートアドレスからエンドアドレスまでのデータを受信して書き込み
        for(lp1=0; lp1 <= (e_adrs-s_adrs);lp1++){
          rdata=rcv1byte();
          file_w.write(rdata);
        }
        file_w.close();
        snd1byte(0x00);
      }else{
        snd1byte(0xf1);
        sdinit();
      }
    }else{
      snd1byte(0xf1);
      sdinit();
    }
  }
}

void loop()
{
  digitalWrite(PB0PIN,LOW);
  digitalWrite(PB1PIN,LOW);
  digitalWrite(PB2PIN,LOW);
  digitalWrite(PB3PIN,LOW);
  digitalWrite(PB4PIN,LOW);
  digitalWrite(PB5PIN,LOW);
  digitalWrite(PB6PIN,LOW);
  digitalWrite(PB7PIN,LOW);
  digitalWrite(FLGPIN,LOW);
//コマンド取得待ち
////    Serial.println("COMMAND WAIT");
  byte cmd = rcv1byte();
////    Serial.println(cmd,HEX);
  if (eflg == false){
    switch(cmd) {
//41hでファイルリスト出力
      case 0x41:
////    Serial.println("FILE LIST START");
//状態コード送信(OK)
        snd1byte(0x00);
        sdinit();
        dirlist();
        break;
//42hでLOADFILEOPEN
      case 0x42:
////    Serial.println("LOADFILEOPEN");
//状態コード送信(OK)
        snd1byte(0x00);
        loadopen();
        break;
//43hでSAVEFILEOPEN
      case 0x43:
////    Serial.println("SAVEFILEOPEN");
//状態コード送信(OK)
        snd1byte(0x00);
        saveopen();
        break;
//44h:sload
      case 0x44:
////    Serial.println("sload START");
//状態コード送信(OK)
        snd1byte(0x00);
        sload();
////  delay(1500);
        break;
//45h:sbload
      case 0x45:
////    Serial.println("sbload START");
//状態コード送信(OK)
        snd1byte(0x00);
        sbload();
////  delay(1500);
        break;
//46h:ssave
      case 0x46:
////    Serial.println("ssave START");
//状態コード送信(OK)
        snd1byte(0x00);
        ssave();
////  delay(1500);
        break;
//47h:sbsave
      case 0x47:
////    Serial.println("sbsave START");
//状態コード送信(OK)
        snd1byte(0x00);
        sbsave();
////  delay(1500);
        break;

//70h:m5 BIN SAVE
      case 0x70:
////    Serial.println("m5 BIN SAVE START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_bin_save();
        break;
//71h:m5 BIN LOAD
      case 0x71:
////    Serial.println("m5 BIN LOAD START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_bin_load();
        break;
//72h:m5 RAW LOAD
      case 0x72:
////    Serial.println("m5 RAW LOAD START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_raw_load();
        break;
//73h:m5 BASIC LOAD
      case 0x73:
////    Serial.println("m5 BASIC LOAD START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_bas_load();
        break;
//74h:m5 BASIC SAVE
      case 0x74:
////    Serial.println("m5 BASIC SAVE START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_bas_save();
        break;
//75h:m5 KILL
      case 0x75:
////    Serial.println("m5 KILL START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_kill();
        break;
//76h:m5 NAME
      case 0x76:
////    Serial.println("m5 NAME START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_name();
        break;
//77h:m5 COPY
      case 0x77:
////    Serial.println("m5 COPY START");
//状態コード送信(OK)
        snd1byte(0x00);
        m5_copy();
        break;
//83hでファイルリスト出力(m5)
      case 0x83:
////    Serial.println("m5 FILE LIST START");
//状態コード送信(OK)
        snd1byte(0x00);
        sdinit();
        m5_dirlist();
        break;
//84h:m5 CHK
      case 0x84:
////    Serial.println("m5 CHK START");
//状態コード送信(OK)
        snd1byte(0x00);
        break;	

      default:
//状態コード送信(CMD ERROR)
        snd1byte(0xF4);
    }
  } else {
//状態コード送信(ERROR)
    snd1byte(0xF0);
    sdinit();
  }
}

//(m5)BASICプログラムのLOAD処理
void m5_bas_load(void){
  boolean flg = false;
  unsigned char rdata;
//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){

//ファイルが存在しなければERROR
    if (SD.exists(f_name) == true){
//ファイルオープン
      file_r = SD.open( f_name, FILE_READ );

      if( true == file_r ){
//f_length設定
        f_length = file_r.size();
        if ( f_length < 10 ){
          snd1byte(0xf2);
          sdinit();
          flg = false;
        }
//状態コード送信(OK)
        snd1byte(0x00);
        flg = true;
      } else {
        snd1byte(0xf0);
        sdinit();
        flg = false;
      }
    }else{
      snd1byte(0xf1);
      sdinit();
      flg = false;
    }
  }else{
    snd1byte(0xf3);
    flg = false;
  }

//良ければファイルエンドまで読み込みを続行する
  if (flg == true) {
    int rdata = 0;
      
//ヘッダー読み込み
    rdata = file_r.read();
    f_length--;
//ヘッダー送信
    snd1byte(rdata);

//ヘッダーが0xd3なら続行、違えばエラー
    if (rdata == 0xd3){

//ブロック数、端数算出
      s_len1 = f_length / 255;
      s_len2 = f_length % 255;

//実データ送信
//0xFFブロック
      while (s_len1 > 0){

//データ長を送信
        snd1byte(0xff);

        for (unsigned int lp1 = 1;lp1 <= 255;lp1++){
//実データを読み込んで送信
          rdata = file_r.read();
          snd1byte(rdata);
        }
        s_len1--;
      }

//データ長を送信
      snd1byte(s_len2);

//端数ブロック処理
      if (s_len2 > 0){
        for (unsigned int lp1 = 1;lp1 <= s_len2;lp1++){
//実データを読み込んで送信
          rdata = file_r.read();
          snd1byte(rdata);
        }
        snd1byte(0x00);
      }
    }
    file_r.close();
  }
}

//(m5)BASICプログラムのSAVE処理
void m5_bas_save(void){
unsigned int lp1;

//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){

//オープン中のファイルがあればクローズ（無いと思うけど）
    if( true == file_w ){
      file_w.close();
    }
  
//ファイルが存在すればdelete
    if (SD.exists(f_name) == true){
      SD.remove(f_name);
    }
//ファイルオープン
    file_w = SD.open( f_name, FILE_WRITE );
    if( true == file_w ){
//状態コード送信(OK)
      snd1byte(0x00);

//スタートアドレス取得
      s_adrs1 = rcv1byte();
      s_adrs2 = rcv1byte();
//スタートアドレス算出
      s_adrs = s_adrs1+s_adrs2*256;
//エンドアドレス取得
      s_adrs1 = rcv1byte();
      s_adrs2 = rcv1byte();
//エンドアドレス算出
      e_adrs = s_adrs1+s_adrs2*256;
//ヘッダー 0xD3書き込み
      file_w.write(char(0xD3));
//実データ (e_adrs - s_adrs +1)を受信、書き込み
      for (lp1 = s_adrs;lp1 <= e_adrs;lp1++){
        file_w.write(rcv1byte());
      }
      file_w.close();
    } else {
      snd1byte(0xf0);
      sdinit();
    }
  }else{
    snd1byte(0xf3);
  }
}

//(m5)KILL処理
void m5_kill(void){

//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){
  
//状態コード送信(OK)
      snd1byte(0x00);
//ファイルが存在すればdelete
    if (SD.exists(f_name) == true){
      SD.remove(f_name);
//状態コード送信(OK)
      snd1byte(0x00);
    }else{
      snd1byte(0xf1);
      sdinit();
    }
  }else{
    snd1byte(0xf3);
  }
}

//(m5)NAME処理
void m5_name(void){

//DOSファイル名1取得
  receive_name(f_name);
//ファイル名1の指定が無ければエラー
  if (f_name[0]!=0x00){
  
//状態コード送信(OK)
    snd1byte(0x00);

//DOSファイル名2取得
    receive_name(w_name);
//ファイル名2の指定が無ければエラー
    if (w_name[0]!=0x00){

//状態コード送信(OK)
      snd1byte(0x00);

//ファイル1が存在すればrename
      if (SD.exists(f_name) == true){

//ファイル2が存在すればエラー
        if (SD.exists(w_name) == false){

          SD.rename(f_name,w_name);

//状態コード送信(OK)
          snd1byte(0x00);
        }else{
          snd1byte(0xf4);
          sdinit();
        }
      }else{
        snd1byte(0xf5);
        sdinit();
      }
    }else{
      snd1byte(0xf3);
      sdinit();
    }
  }else{
    snd1byte(0xf3);
  }
}


//(m5)COPY処理
void m5_copy(void){

  unsigned int lp1;
  unsigned char bufdata[256];
//DOSファイル名1取得
  receive_name(f_name);
//ファイル名1の指定が無ければエラー
  if (f_name[0]!=0x00){
  
//状態コード送信(OK)
    snd1byte(0x00);

//DOSファイル名2取得
    receive_name(w_name);
//ファイル名2の指定が無ければエラー
    if (w_name[0]!=0x00){

//状態コード送信(OK)
      snd1byte(0x00);

//ファイル1が存在すればcopy
      if (SD.exists(f_name) == true){

//ファイル2が存在すればエラー
        if (SD.exists(w_name) == false){

//ファイル1オープン
          file_r = SD.open( f_name, FILE_READ );
          if( true == file_r ){

//f_length設定
            f_length = file_r.size();
//ブロック数、端数算出
            s_len1 = f_length / 255;
            s_len2 = f_length % 255;

//ファイル2オープン
            file_w = SD.open( w_name, FILE_WRITE );
            if( true == file_w ){

//読み込んで書く
//0xFFブロック
              while (s_len1 > 0){

                for (lp1 = 1;lp1 <= 255;lp1++){
                  bufdata[lp1-1] = file_r.read();
                }
                delay(100);
                for (lp1 = 1;lp1 <= 255;lp1++){
                  file_w.write(bufdata[lp1-1]);
                }
                delay(100);
                s_len1--;
              }

//端数ブロック処理
              if (s_len2 > 0){
                for (lp1 = 1;lp1 <= s_len2;lp1++){
                  bufdata[lp1-1] = file_r.read();
                }
                delay(100);
                for (lp1 = 1;lp1 <= s_len2;lp1++){
                  file_w.write(bufdata[lp1-1]);
                }
                delay(100);
              }
              file_w.close();
            }
            file_r.close();

//状態コード送信(OK)
            snd1byte(0x00);
          }else{
            snd1byte(0xf0);
            sdinit();
          }
        }else{
          snd1byte(0xf4);
          sdinit();
        }
      }else{
        snd1byte(0xf5);
        sdinit();
      }
    }else{
      snd1byte(0xf3);
    }
  }else{
    snd1byte(0xf3);
  }
}

// (m5)BIN LOAD
void m5_bin_load(void){
  boolean flg = false;
  unsigned char rdata;
//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){

//ファイルが存在しなければERROR
    if (SD.exists(f_name) == true){
//ファイルオープン
      file_r = SD.open( f_name, FILE_READ );

      if( true == file_r ){
//f_length設定
        f_length = file_r.size();
        if ( f_length < 4 ){
          snd1byte(0xf2);
          sdinit();
          flg = false;
        }
//状態コード送信(OK)
        snd1byte(0x00);
        flg = true;
      } else {
        snd1byte(0xf0);
        sdinit();
        flg = false;
      }
    }else{
      snd1byte(0xf1);
      sdinit();
      flg = false;
    }
  }else{
    snd1byte(0xf3);
    flg = false;
  }

//良ければファイルエンドまで読み込みを続行する
  if (flg == true) {
    int rdata = 0;
      
//ヘッダー読み込み
    rdata = file_r.read();
    f_length--;
//ヘッダー送信
    snd1byte(rdata);

//ヘッダーが0x3aなら続行、違えばエラー
    if (rdata == 0x3a){
//START ADDRESS HIを送信
      s_adrs1 = file_r.read();
      f_length--;
      snd1byte(s_adrs1);

//START ADDRESS LOを送信
      s_adrs2 = file_r.read();
      f_length--;
      snd1byte(s_adrs2);

//ブロック数、端数算出
      s_len1 = f_length / 255;
      s_len2 = f_length % 255;

//実データ送信
//0xFFブロック
      while (s_len1 > 0){

//データ長を送信
        snd1byte(0xff);

        for (unsigned int lp1 = 1;lp1 <= 255;lp1++){
//実データを読み込んで送信
          rdata = file_r.read();
          snd1byte(rdata);
        }
        s_len1--;
      }

//データ長を送信
      snd1byte(s_len2);

//端数ブロック処理
      if (s_len2 > 0){
        for (unsigned int lp1 = 1;lp1 <= s_len2;lp1++){
//実データを読み込んで送信
          rdata = file_r.read();
          snd1byte(rdata);
        }
        snd1byte(0x00);
      }
    }
    file_r.close();
  }
}

// (m5)BIN SAVE
void m5_bin_save(void){
  byte  r_data;
//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){
  
//オープン中のファイルがあればクローズ（無いと思うけど）
    if( true == file_w ){
      file_w.close();
    }

//ファイルが存在すればdelete
    if (SD.exists(f_name) == true){
      SD.remove(f_name);
    }
//ファイルオープン
    file_w = SD.open( f_name, FILE_WRITE );
    if( true == file_w ){
//状態コード送信(OK)
      snd1byte(0x00);

//ヘッダー 0x3A書き込み
      file_w.write(char(0x3A));
//先頭アドレス取得、書き込み
      s_adrs1 = rcv1byte();
      s_adrs2 = rcv1byte();
      file_w.write(s_adrs2);
      file_w.write(s_adrs1);
//スタートアドレス取得
      s_adrs1 = rcv1byte();
      s_adrs2 = rcv1byte();
//スタートアドレス算出
      s_adrs = s_adrs1+s_adrs2*256;
//エンドアドレス取得
      s_adrs1 = rcv1byte();
      s_adrs2 = rcv1byte();
//エンドアドレス算出
      e_adrs = s_adrs1+s_adrs2*256;
//ファイル長算出、ブロック数算出
      w_length = e_adrs - s_adrs + 1;
      w_len1 = w_length / 255;
      w_len2 = w_length % 255;

//実データ受信、書き込み
//0xFFブロック
      while (w_len1 > 0){
	for (unsigned int lp1 = 1;lp1 <= 255;lp1++){
	  r_data = rcv1byte();
	  file_w.write(r_data);
	}
	w_len1--;
      }

//端数ブロック処理
      if (w_len2 > 0){
	for (unsigned int lp1 = 1;lp1 <= w_len2;lp1++){
	  r_data = rcv1byte();
	  file_w.write(r_data);
	}
      }

      file_w.close();
    }else{
      snd1byte(0xf0);
      sdinit();
    }
  }else{
    snd1byte(0xf3);
  }
}


// (m5)RAW LOAD
void m5_raw_load(void){
  boolean flg = false;
  unsigned char rdata;
//DOSファイル名取得
  receive_name(f_name);
//ファイル名の指定が無ければエラー
  if (f_name[0]!=0x00){

//ファイルが存在しなければERROR
    if (SD.exists(f_name) == true){
//ファイルオープン
      file_r = SD.open( f_name, FILE_READ );

      if( true == file_r ){
//f_length設定
        f_length = file_r.size();
//状態コード送信(OK)
        snd1byte(0x00);
        flg = true;
      } else {
        snd1byte(0xf0);
        sdinit();
        flg = false;
      }
    }else{
      snd1byte(0xf1);
      sdinit();
      flg = false;
    }
  }else{
    snd1byte(0xf3);
    flg = false;
  }

//良ければファイルエンドまで読み込みを続行する
  if (flg == true) {

//ブロック数、端数算出
    s_len1 = f_length / 255;
    s_len2 = f_length % 255;

//実データ送信
//0xFFブロック
    while (s_len1 > 0){

//データ長を送信
      snd1byte(0xff);

      for (unsigned int lp1 = 1;lp1 <= 255;lp1++){
//実データを読み込んで送信
        rdata = file_r.read();
        snd1byte(rdata);
      }
      s_len1--;
    }

//データ長を送信
    snd1byte(s_len2);

//端数ブロック処理
    if (s_len2 > 0){
      for (unsigned int lp1 = 1;lp1 <= s_len2;lp1++){
//実データを読み込んで送信
        rdata = file_r.read();
        snd1byte(rdata);
      }
      snd1byte(0x00);
    }
    file_r.close();
  }        
}

// SD-CARDのFILELIST
void m5_dirlist(void){
  int dspline=20;

//比較文字列取得 32+1文字まで
  receive_name(c_name);
//
  File file2 = SD.open( "/" );
  if( file2 == true ){
//状態コード送信(OK)
    snd1byte(0x00);

    File entry =  file2.openNextFile();
    int cntl2 = 0;
    unsigned int br_chk =0;
    int page = 1;
//全件出力の場合には10件出力したところで一時停止、キー入力により継続、打ち切りを選択
    while (br_chk == 0) {
      if(entry){
        entry.getName(f_name,36);
        unsigned int lp1=0;
//一件送信
//比較文字列でファイルネームを先頭から比較して一致するものだけを出力
        if (f_match(f_name,c_name)){
//ファイルサイズ出力
          w_name[0]=0x20;
          w_name[1]=0x00;
          f_length = entry.size();
          if (f_length > 1024){
            f_length /= 1024;
            strcpy(w_name,"K");
            if (f_length > 1024){
              f_length /= 1024;
              strcpy(w_name,"M");
              if (f_length > 1024){
                f_length /= 1024;
                strcpy(w_name,"G");
              }
            }
          }
          if ((f_length/1000)!=0){
            snd1byte(0x30+f_length/1000);
          }else{
            snd1byte(0x20);
          }
          if (f_length > 999 || ((f_length%1000)/100)!=0){
            snd1byte(0x30+(f_length%1000)/100);
          }else{
            snd1byte(0x20);
          }
          if (f_length > 99 || ((f_length%100)/10)!=0){
            snd1byte(0x30+(f_length%100)/10);
          }else{
            snd1byte(0x20);
          }
          snd1byte(0x30+(f_length%10));
          snd1byte(w_name[0]);

          snd1byte(0x20);
          while (lp1<=36 && f_name[lp1]!=0x00){
          snd1byte(upper(f_name[lp1]));
          lp1++;
          }
          snd1byte(0x0D);
          snd1byte(0x00);
          cntl2++;
        }
      }

      entry =  file2.openNextFile();
// 次のファイルはあるか？
      if (entry){
// CNTL2 > 表示件数-1
        if (cntl2 > (dspline-1)){
//継続・打ち切り選択指示要求
          snd1byte(0xfe);
//選択指示受信(0:継続 以外:打ち切り)
          br_chk = rcv1byte();
          cntl2 = 0;
        }
      }else{
        br_chk=1;
      }
    }
//処理終了指示
    snd1byte(0xFF);
    snd1byte(0x00);
  }else{
    snd1byte(0xf0);
    sdinit();
  }
}