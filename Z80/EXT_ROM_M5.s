; EXT_ROM_M5.s
;  SORD m5 メモリマッパー (+SD)用 SDアクセス&マッパー切替プログラム
;
;  (アセンブラはZASM64使用)
;
;2024/1 PC-8001_SDをベースに作成
;2024/6 コマンドライン化
;       （プログラムから呼び出す場合は、自分でコマンドラインを設定する必要がある）
;
;使い方
;call &6000:!F(/ファイル名/)			:ファイル一覧出力、ファイル名は出力マスクで省略可
;call &6000:!L/ファイル名/			:BASICファイルロード
;call &6000:!S/ファイル名/			:BASICファイルセーブ
;call &6000:!V/ファイル名/			:BASICファイルベリファイ
;call &6000:!K/ファイル名/			:ファイル削除
;call &6000:!N/ファイル名1/ファイル名2/		:ファイル名変更（ファイル名1から2へ）ファイル名2があった場合エラー
;call &6000:!C/ファイル名1/ファイル名2/		:ファイルコピー（ファイル名1から2へ）ファイル名2があった場合エラー
;call &6000:!Azzzz/ファイル名/			:RAWファイルロード
;call &6000:!R(zzzz)/ファイル名/		:バイナリファイルロード、ロードアドレス省略時はセーブ時のアドレスを使用	
;call &6000:!Wxxxxyyyy(zzzz)/ファイル名/	:バイナリファイルセーブ、ロードアドレス省略時はセーブ先頭アドレスと同じ値
;call &6000:!Maabbccdd				:マッパー設定＋0000Hから実行(IPL）

;'!'は'rem 'でも可、BASIC-Iは!がコメントではないので、remを使用する
;例 call &6000:rem F

;xxxx:セーブ先頭アドレス
;yyyy:セーブ終了アドレス
;zzzz:ロードアドレス
;ファイル名は'/'で囲む、最大32文字（スペース可能）
;先頭の'/'が無い場合、ファイル名は無指定扱い（Fコマンド以外はエラーになる）
;終端の'/'以降は全て無視
;ファイル名無効文字は'\/:*?"<>|'（指定した場合、自動で削除する）
;aabbccdd:ページ0～3へ設定するレジスタ値（00H～3FH）FF指定で切替なし

;ロード時RAMかどうかは判断していない
;BASICファイルロードは管理領域までとしているが、それ以外はFFFFHまで無条件にロードする

;ファイルフォーマット（内容は厳密にチェックしていない。間違ったファイルをロードした場合、動作は保証されません）
;BASIC
; D3H + BASIC中間コードバイナリ
;バイナリ
; 3AH + ロードアドレス(2バイト) + 実データバイナリ
;RAW
; 実データバイナリのみ

;プログラムからコマンドを実行する場合
;（例:BASIC-GでRAMマッパー31の後半(2000H)にbasici.romをRAWロードして、ページ0をマッパー31に切り替えて再起動）
; 10 len 24:AD=&73B9:out &7E,&3F
; 20 WK$="call :!rA000/basici.rom/"
; 30 for I=0 to len(WK$)
; 40 poke AD+I,ascii(mid$(WK$,I+1,1))
; 50 next
; 60 call &6000
; 70 WK$="call :!m3F000000"
; 80 for I=0 to len(WK$)
; 90 poke AD+I,ascii(mid$(WK$,I+1,1))
; 100 next
; 110 call &6000

;***************************************

;以下BASIC-GとIでワークエリアが違うので、バイナリば個別に必要（以下のコメントを入れ替えて作成）
;BASIC-G
ANALYS		EQU	2A25H		;BASICコード解析？
BASSRT		EQU	726AH		;プログラムテキスト開始位置
VARBGN		EQU	726CH		;変数領域開始位置
VAREND		EQU	726EH		;変数領域終了位置
RAMEND		EQU	7270H		;BASIC使用可能最終アドレス
LASTLB		EQU	727AH		;プログラム最終実行アドレス
CMDLIN		EQU	73B9H		;コマンドラインバッファ先頭アドレス

;BASIC-I
;ANALYS		EQU	2EE3H		;BASICコード解析？
;BASSRT		EQU	71BFH		;プログラムテキスト開始位置
;VARBGN		EQU	71C1H		;変数領域開始位置
;VAREND		EQU	71C3H		;変数領域終了位置
;RAMEND		EQU	71C5H		;BASIC使用可能最終アドレス
;LASTLB		EQU	71CFH		;プログラム最終実行アドレス
;CMDLIN		EQU	72E2H		;コマンドラインバッファ先頭アドレス

;***************************************
CONOUT		EQU	1082H		;CRTへの1バイト出力
KYSCAN		EQU	0756H		;1文字キー入力待ち
MSGOUT		EQU	105CH		;文字列の出力
MONCLF		EQU	10EDH		;CRコード及びLFコードの表示

FILSEP		EQU	2FH		;ファイル名区切り文字 '/'
MAXREG		EQU	3FH		;マッパーレジスタ最大値

PPI_A		EQU	78H		;8255 IOアドレス
PPI_B		EQU	PPI_A+1
PPI_C		EQU	PPI_A+2
PPI_R		EQU	PPI_A+3

;8255 PORT アドレス 78H～7BH
;78H PORTA 送信データ(下位4ビット)
;79H PORTB 受信データ(8ビット)
;
;7AH PORTC Bit
;7 IN  CHK
;6 IN
;5 IN
;4 IN 
;3 OUT
;2 OUT FLG
;1 OUT
;0 OUT
;
;7BH コントロールレジスタ


;コマンドラインからパラメータを読み込む
;73B9H～ コマンドライン文字列が入る（ただしプログラムから実行した場合は入らない）
;例えば、BASIC-Gで
;call &6000:!コマンド
;とすると、callが実行され、!以降はコメントなのでエラーにはならない。
;call &6000を実行された時点で、73B9Hには:以降も残っているので
;73B9Hから'!'をサーチし、それ以降をパラメータとして処理している

;コマンド実行時に、マルチステートメント以降のコマンドを書き換えても変わらない
;よって、CMDLINからをワークとして使用できる
;（call a:!L/ファイル名/ ←ファイル名はそのまま使用したい、構文的に10バイトまで使える)
;0000(1byte) : コマンドコード（FLSKRW）
;0001(2byte) : xxxx または zzzz有効フラグ（Rコマンド時、前1バイトのみ使用）
;0003(2byte) : yyyy または ファイル名の先頭アドレス（名称変更,コピー時）
;0005(2byte) : zzzz
;0007(2byte) : ファイル名先頭アドレス（格納先ファイル名は文字列（最大32バイト)+00H）

WKBFCMD		EQU	(CMDLIN)
WKBFSTR		EQU	(CMDLIN+1)
WKBFEND		EQU	(CMDLIN+3)
WKBFEXE		EQU	(CMDLIN+5)
WKBFFIL		EQU	(CMDLIN+7)


		ORG	6000H

;*** コマンド取得 call &6000:!x    の !x 
;                 call &6000:REM x の REM x を抽出する ***************************************
GETCMD:
		LD	DE,CMDLIN	;コマンド行文字列先頭－１
		LD	HL,CMDCHKSTR	;コマンドチェック文字列
GETCMD1:
		LD	A,(HL)
		AND	A
		JR	Z,GETCMD2	;チェック文字列の順番で全て一致
		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CP	0DH
		RET	Z		;コマンド行が改行なら終了（無処理）
		CP	(HL)
		JR	NZ,GETCMD1	;一致しない場合は次の文字へ
		INC	HL
		JR	GETCMD1
GETCMD2:
		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CP	21H		;'!'
		JR	Z,GETCMD4
		CP	52H		;'R'
		JR	Z,GETCMD3
		CP	0DH		;コマンド行が改行なら終了（コマンドエラー）
		JP	Z,CMDERR1
		JR	GETCMD2
GETCMD3:
		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CP	45H		;'E'
		JP	NZ,CMDERR1	;↑でないなら終了（コマンドエラー）
		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CP	4DH		;'M'
		JP	NZ,CMDERR1	;↑でないなら終了（コマンドエラー）
		LD	A,(DE)
		INC	DE
		CP	20H		;' '
		JP	NZ,CMDERR1	;↑でないなら終了（コマンドエラー）
GETCMD4:
		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CP	46H		;'F' files
		JP	Z,GETPARA5
		CP	4CH		;'L' load
		JP	Z,GETPARA5
		CP	53H		;'S' save
		JP	Z,GETPARA5
		CP	56H		;'V' verify
		JP	Z,GETPARA5
		CP	4BH		;'K' kill
		JP	Z,GETPARA5
		CP	4EH		;'N' name
		JP	Z,GETPARA12
		CP	43H		;'C' copy
		JP	Z,GETPARA12
		CP	41H		;'A' raw
		JP	Z,GETPARA10
		CP	52H		;'R' read
		JP	Z,GETPARA3
		CP	57H		;'W' write
		JP	Z,GETPARA1
		CP	4DH		;'M' mapper
		JP	NZ,CMDERR1	;↑以外なら終了（コマンドエラー）
GETPATA11:
		LD	(WKBFCMD),A	;コマンド退避
		CALL	HLHEX		;ページ0,1レジスタ獲得
		JP	C,CMDERR2	;16進数以外なら終了（パラメータエラー）
		LD	A,H
		CP	0FFH
		JR	Z,MAPPER1	;FFHなら切替なしとする
		CP	MAXREG+1
		JP	NC,CMDERR7	;レジスタ最大値を超えてたら終了（パラメータエラー）
MAPPER1:
		LD	(WKBFSTR),A
		LD	A,L
		CP	0FFH
		JR	Z,MAPPER2	;FFHなら切替なしとする
		CP	MAXREG+1
		JP	NC,CMDERR7	;レジスタ最大値を超えてたら終了（パラメータエラー）
MAPPER2:
		LD	(WKBFEND),A
		CALL	HLHEX		;ページ2,3レジスタ獲得
		JP	C,CMDERR2	;16進数以外なら終了（パラメータエラー）
		LD	A,H
		CP	0FFH
		JR	Z,MAPPER3	;FFHなら切替なしとする
		CP	MAXREG+1
		JP	NC,CMDERR7	;レジスタ最大値を超えてたら終了（パラメータエラー）
MAPPER3:
		LD	(WKBFEXE),A
		LD	A,L
		CP	0FFH
		JR	Z,MAPPER4	;FFHなら切替なしとする
		CP	MAXREG+1
		JP	NC,CMDERR7	;レジスタ最大値を超えてたら終了（パラメータエラー）
MAPPER4:
		LD	(WKBFFIL),A

		LD	DE,WKBFFIL+1	;実行プログラムをRAMに配置
		LD	BC,13H
		LD	HL,CMDMAPCHG
		LDIR

		LD	A,(WKBFSTR)	;レジスタ値を展開
		CP	0FFH
		JR	Z,MAPPER9	;FFHなら切替なしとする
		LD	(WKBFFIL+1+1),A
MAPPER5:
		LD	A,(WKBFEND)
		LD	(WKBFFIL+1+5),A
		CP	0FFH
		JR	Z,MAPPER10	;FFHなら切替なしとする
MAPPER6:
		LD	A,(WKBFEXE)
		LD	(WKBFFIL+1+9),A
		CP	0FFH
		JR	Z,MAPPER11	;FFHなら切替なしとする
MAPPER7:
		LD	A,(WKBFFIL)
		LD	(WKBFFIL+1+13),A
		CP	0FFH
		JR	Z,MAPPER12	;FFHなら切替なしとする
MAPPER8:
		JP	WKBFFIL+1	;RAMの実行プログラムへジャンプ
MAPPER9:
		XOR	A
		LD	(WKBFFIL+1+2),A
		LD	(WKBFFIL+1+3),A
		JR	MAPPER5
MAPPER10:
		XOR	A
		LD	(WKBFFIL+1+6),A
		LD	(WKBFFIL+1+7),A
		JR	MAPPER6
MAPPER11:
		XOR	A
		LD	(WKBFFIL+1+10),A
		LD	(WKBFFIL+1+11),A
		JR	MAPPER7
MAPPER12:
		XOR	A
		LD	(WKBFFIL+1+14),A
		LD	(WKBFFIL+1+15),A
		JR	MAPPER8
GETPARA12:
		LD	(WKBFCMD),A	;コマンド退避
GETPARA13:
		LD	A,(DE)
		INC	DE
		CP	FILSEP
		JR	NZ,GETPARA17	;ファイル名区切り文字以外ならファイル名無指定と判断
		LD	(WKBFEND),DE
		LD	(WKBFFIL),DE
GETPARA14:
		LD	A,(DE)
		CP	FILSEP		;ファイル名区切り文字（１つめ）
		JR	Z,GETPARA16
		CP	0DH		;１つめで改行ならファイル名無指定と判断
		JP	Z,GETPARA9
		INC	DE
		JR	GETPARA14
GETPARA16:
		XOR	A
		LD	(DE),A		;ファイル名の終端をnullにする
		INC	DE
		LD	(WKBFFIL),DE
		JP	GETPARA7
GETPARA17:
		DEC	DE
		LD	(WKBFEND),DE
		LD	(WKBFFIL),DE
		JP	GETPARA9
GETPARA1:
		LD	(WKBFCMD),A	;コマンド退避
		CALL	HLHEX		;保存開始アドレス獲得
		JP	C,CMDERR2	;16進数以外なら終了（パラメータエラー）
		LD	(WKBFSTR),HL
		CALL	HLHEX		;保存終了アドレス獲得
		JP	C,CMDERR2	;16進数以外なら終了（パラメータエラー）
		LD	(WKBFEND),HL
		PUSH	DE
		CALL	HLHEX		;ロードアドレス獲得
		JR	C,GETPARA2	;16進数以外なら無指定と判断する
		POP	BC		;スタックのDEを破棄
		LD	(WKBFEXE),HL
		JR	GETPARA6
GETPARA2:
		POP	DE
		LD	HL,(WKBFSTR)
		LD	(WKBFEXE),HL	;ロードアドレス＝保存開始アドレスとする
		JR	GETPARA6
GETPARA3:
		LD	(WKBFCMD),A	;コマンド退避
		PUSH	DE
		CALL	HLHEX		;ロードアドレス獲得
		JR	C,GETPARA4	;16進数以外なら無指定と判断する
		POP	BC		;スタックのDEを破棄
		LD	A,01H
		LD	(WKBFSTR),A
		LD	(WKBFEXE),HL	
		JR	GETPARA6
GETPARA10:
		LD	(WKBFCMD),A	;コマンド退避
		CALL	HLHEX		;ロードアドレス獲得
		JP	C,CMDERR2	;16進数以外なら終了（パラメータエラー）
		LD	(WKBFEXE),HL
		JR	GETPARA6
GETPARA4:
		POP	DE
		XOR	A
		LD	(WKBFSTR),A	;ロードアドレス＝保存時のアドレスとする
		JR	GETPARA6
GETPARA5:
		LD	(WKBFCMD),A	;コマンド退避
GETPARA6:
		LD	A,(DE)
		INC	DE
		CP	FILSEP
		JR	NZ,GETPARA8	;ファイル名区切り文字以外ならファイル名無指定と判断
		LD	(WKBFFIL),DE
GETPARA7:
		LD	A,(DE)
		CP	FILSEP		;ファイル名区切り文字
		JR	Z,GETPARA9
		CP	0DH		;改行
		JR	Z,GETPARA9
		INC	DE
		JR	GETPARA7
GETPARA8:
		DEC	DE
		LD	(WKBFFIL),DE
GETPARA9:
		XOR	A
		LD	(DE),A		;ファイル名の終端をnullにする

;*** コマンド振り分け ***************************************
CMDMAIN:
		CALL	INIT		;8255を初期化
		CALL	IOCHK		;MSX_SDチェック
		CP	0FFH
		JP	Z,CMDERR6	;IOエラー

		LD	A,(WKBFCMD)
		CP	46H		;'F' files
		JP	Z,CMDFILES
		CP	4CH		;'L' load
		JP	Z,CMDLOAD
		CP	53H		;'S' save
		JP	Z,CMDSAVE
		CP	56H		;'V' verify
		JP	Z,CMDVERIFY
		CP	4BH		;'K' kill
		JP	Z,CMDKILL
		CP	4EH		;'N' name
		JP	Z,CMDNAME
		CP	43H		;'C' copy
		JP	Z,CMDCOPY
		CP	41H		;'A' raw
		JP	Z,CMDRAW
		CP	52H		;'R' read
		JR	Z,CMDREAD
		CP	57H		;'W' write
		JP	NZ,CMDERR1	;ありえないけど↑以外なら終了（コマンドエラー）

;*** BIN SAVE ***************************************
CMDWRITE:
		LD	HL,(WKBFEND)
		LD	DE,(WKBFSTR)
		SBC	HL,DE
		JP	C,CMDERR2	;開始 > 終了なら終了（パラメータエラー）

		LD	HL,(WKBFFIL)	;ファイル名
		LD	A,70H		;コマンド70Hを送信
		CALL	STCMD	
		JP	NZ,RETBC	;エラー

		LD	HL,(WKBFEXE)	;ロードアドレスを送信
		LD	A,L
		CALL	SNDBYTE
		LD	A,H
		CALL	SNDBYTE

		LD	HL,(WKBFSTR)	;セーブ先頭アドレスを送信
		LD	A,L
		CALL	SNDBYTE
		LD	A,H
		CALL	SNDBYTE

		LD	DE,(WKBFEND)	;セーブ終了アドレスを送信
		LD	A,E
		CALL	SNDBYTE
		LD	A,D
		CALL	SNDBYTE
CMDWRITE1:
		LD	A,(HL)		;先頭～終了までを送信
		CALL	SNDBYTE
		LD	A,H
		CP	D
		JR	NZ,CMDWRITE2
		LD	A,L
		CP	E
		JP	Z,RETBC		;HL = DE までLOOP
CMDWRITE2:
		INC	HL
		JR	CMDWRITE1

;*** BIN LOAD ***************************************
CMDREAD:
		LD	A,71H		;コマンド71Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー

		CALL	RCVBYTE		;ヘッダー受信
		CP	3AH
		JP	NZ,CMDERR3	;3AHでなければエラー

		LD	HL,(WKBFEXE)
		LD	A,(WKBFSTR)
		CP	01H
		JR	Z,CMDREAD1	;ロードアドレス＝パラメータとする
		CALL	RCVBYTE
		LD	HL,WKBFEXE+1
		LD	(HL),A
		DEC	HL
		CALL	RCVBYTE
		LD	(HL),A
		JR	CMDREAD2
CMDREAD1:
		CALL	RCVBYTE		;保存アドレス廃棄
		CALL	RCVBYTE
CMDREAD2:
		JR	CMDRAW0

;*** RAW ***************************************
CMDRAW:
		LD	A,72H		;コマンド72Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー

		LD	HL,(WKBFEXE)	;ロードアドレス設定
CMDRAW0:
		LD	DE,0FFFFH	;使用可能最終アドレス
CMDRAW1:
		CALL	RCVBYTE		;データ長
		AND	A
		JP	Z,RETBC		;データ長が0なら終了
		LD	B,A
CMDRAW2:
		CALL	RCVBYTE		;実データ
		LD	(HL),A

		PUSH	HL
		SBC	HL,DE
		POP	HL
		JR	Z,CMDRAW4	;使用可能まで達したら空読みモード（メモリ不足）

		INC	HL
		DJNZ	CMDRAW2
		JR	CMDRAW1

CMDRAW4:				;空読みモード
		LD	H,01H
		DJNZ	CMDRAW6
		LD	H,00H
CMDRAW5:
		CALL	RCVBYTE		;データ長
		AND	A
		JR	Z,CMDRAW7	;データ長が0なら終了（メモリ不足）
		LD	B,A
CMDRAW6:
		CALL	RCVBYTE		;実データ
		DJNZ	CMDRAW6
		JR	CMDRAW5
CMDRAW7:
		LD	A,H
		AND	A
		JP	NZ,CMDERR5	;使用可能まで達して空読みデータ有の場合はメモリ不足
		JP	RETBC

;*** BASIC LOAD ***************************************
CMDLOAD:
		LD	A,73H		;コマンド73Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー

		CALL	RCVBYTE		;ヘッダー受信
		CP	0D3H
		JP	NZ,CMDERR3	;D3Hでなければエラー

		LD	HL,(BASSRT)	;BASICプログラム格納開始位置をHLに設定
		LD	(VARBGN),HL	;BASIC最終位置を更新
		LD	(VAREND),HL	;変数領域最終位置を更新
		LD	DE,(RAMEND)	;BASIC使用可能最終アドレス
CMDLOAD1:
		CALL	RCVBYTE		;データ長
		AND	A
		JR	Z,CMDLOAD3	;データ長が0なら終了
		LD	B,A
CMDLOAD2:
		CALL	RCVBYTE		;実データ
		LD	(HL),A

		PUSH	HL
		SBC	HL,DE
		POP	HL
		JR	Z,CMDRAW4	;使用可能まで達したら空読みモード（メモリ不足）

		INC	HL
		DJNZ	CMDLOAD2
		JP	CMDLOAD1
CMDLOAD3:
		LD	(VARBGN),HL	;BASIC最終位置を更新
		LD	(VAREND),HL	;変数領域最終位置を更新
		LD	(HL),0000H	;変数領域を初期化

		JP	RETBC

;*** BASIC VERYFY ***************************************
CMDVERIFY:
		LD	A,73H		;コマンド73Hを送信(LOADコマンド)
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー

		CALL	RCVBYTE		;ヘッダー受信
		CP	0D3H
		JP	NZ,CMDERR8	;D3Hでなければエラー

		LD	HL,(BASSRT)	;BASICプログラム格納開始位置をHLに設定
CMDVERIFY1:
		CALL	RCVBYTE		;データ長
		AND	A
		JP	Z,RETBC		;データ長が0なら正常終了
		LD	B,A
CMDVERIFY2:
		CALL	RCVBYTE		;実データ
		CP	(HL)
		JP	NZ,CMDVERIFY3	;一致しなかったらエラー空読みモード（エラー）

		INC	HL
		DJNZ	CMDVERIFY2
		JP	CMDVERIFY1

CMDVERIFY3:				;空読みモード
		DJNZ	CMDVERIFY5
CMDVERIFY4:
		CALL	RCVBYTE		;データ長
		AND	A
		JP	Z,CMDERR8	;データ長が0なら終了（ベリファイエラー）
		LD	B,A
CMDVERIFY5:
		CALL	RCVBYTE		;実データ
		DJNZ	CMDVERIFY5
		JP	CMDVERIFY4

;*** KILL ***************************************
CMDKILL:
		LD	A,75H		;コマンド75Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		CALL	RCVBYTE
		AND	A		;00以外ならERROR
		JP	NZ,SDERR
		JP	RETBC

;*** COPY ***************************************
CMDCOPY:
		LD	A,77H		;コマンド77Hを送信
		JR	CMDNAME1

;*** NAME ***************************************
CMDNAME:
		LD	A,76H		;コマンド76Hを送信
CMDNAME1:
		LD	HL,(WKBFEND)	;ファイル名
		CALL	STCMD
		LD	HL,(WKBFFIL)	;ファイル名２	
		CALL	STFS		;ファイルネーム２送信
		AND	A		;00以外ならERROR
		JP	NZ,SDERR
		CALL	RCVBYTE
		AND	A		;00以外ならERROR
		JP	NZ,SDERR
		JP	RETBC

;*** BASIC SAVE ***************************************
CMDSAVE:
		LD	HL,(BASSRT)	;BASICプログラム格納開始位置をHLに設定
		LD	A,(HL)
		INC	HL
		OR	(HL)
		JP	Z,CMDERR4	;BASICプログラムが1行もなければエラー

		CALL	RETNUM		;分岐先アドレスを行番号に戻す

		LD	A,74H		;コマンド74Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー

		LD	HL,(BASSRT)	;BASSRTからVARBGN-1までを送信
		LD	A,L
		CALL	SNDBYTE
		LD	A,H
		CALL	SNDBYTE
		LD	DE,(VARBGN)
		DEC	DE
		LD	A,E
		CALL	SNDBYTE
		LD	A,D
		CALL	SNDBYTE
CMDSAVE1:
		LD	A,(HL)
		CALL	SNDBYTE
		LD	A,H
		CP	D
		JR	NZ,CMDSAVE2
		LD	A,L
		CP	E
		JP	Z,RETBC		;HL = DE までLOOP
CMDSAVE2:
		INC	HL
		JR	CMDSAVE1

;*** FILES ***************************************
CMDFILES:
		LD	A,83H		;コマンド83Hを送信
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	STCMD
		JP	NZ,RETBC	;エラー	
CMDFILES1:
		LD	HL,(WKBFFIL)
CMDFILES2:
		CALL	RCVBYTE
		AND	A
		JR	Z,CMDFILES3	;'00H'を受信したら一行分を表示して改行
		CP	0FFH
		JR	Z,CMDFILES4	;'0FFH'を受信したら終了
		CP	0FEH
		JR	Z,CMDFILES5	;'0FEH'を受信したら一時停止して一文字入力待ち
		LD	(HL),A
		INC	HL
		JR	CMDFILES2
CMDFILES3:
		LD	(HL),A
		LD	HL,(WKBFFIL)
		CALL	MSGOUT
		JR	CMDFILES1
CMDFILES4:
		CALL	RCVBYTE		;状態取得(00H=OK)
		JP	RETBC
CMDFILES5:
		CALL	MONCLF
		LD	HL,MSG_KEY	;pauseプロンプト表示
		CALL	MSGOUT
CMDFILES6:
		CALL	KYSCAN		;1文字入力待ち
		CALL	AZLCNV
		AND	A
		JR	Z,CMDFILES6
		CP	0DH		;RETURNで打ち切り
		JR	Z,CMDFILES7
		XOR	A		;それ以外で継続
		JR	CMDFILES8
CMDFILES7:
		LD	A,0FFH		;0FFH中断コードを送信
CMDFILES8:
		CALL	SNDBYTE
		CALL	MONCLF
		JR	CMDFILES1

;*** 8255初期化 ***************************************
;PORTC下位BITをOUTPUT、上位BITをINPUT、PORTBをINPUT、PORTAをOUTPUT
INIT:
		LD	A,8AH
		OUT	(PPI_R),A
;出力BITをリセット
		XOR	A		;PORTA <- 0
		OUT	(PPI_A),A
		OUT	(PPI_C),A	;PORTC <- 0
		RET

;*** MSX_SD存在チェック ***************************************
IOCHK:
					;コマンド84Hを送信
		LD	A,08H		;上位8H送信

		OUT	(PPI_A),A
		LD	A,05H
		OUT	(PPI_R),A	;PORTC BIT2 <- 1

		LD	B,00H
IOCHK1:
		INC	B
		JR	Z,IOCHK3	;254回チェックしてもCHK=1とならない
		IN	A,(PPI_C)
		AND	80H		;PORTC BIT7 = 1?
		JR	Z,IOCHK1

		LD	A,04H
		OUT	(PPI_R),A	;PORTC BIT2 <- 0

		LD	B,00H
IOCHK2:
		INC	B
		JR	Z,IOCHK3	;254回チェックしてもCHK=1とならない
		IN	A,(PPI_C)
		AND	80H		;PORTC BIT7 = 0?
		JR	NZ,IOCHK2

		LD	A,04H		;下位4H送信
		CALL	SND4BIT

		CALL	RCVBYTE		;結果受信(00H=OK)
		RET
IOCHK3:
		LD	A,0FFH
		RET

;*** 1BYTE受信 ***************************************
;受信DATAをAレジスタにセットしてリターン
RCVBYTE:
		CALL	F1CHK		;PORTC BIT7が1になるまでLOOP
		IN	A,(PPI_B)	;PORTB -> A
		PUSH 	AF
		LD	A,05H
		OUT	(PPI_R),A	;PORTC BIT2 <- 1
		CALL	F2CHK		;PORTC BIT7が0になるまでLOOP
		LD	A,04H
		OUT	(PPI_R),A	;PORTC BIT2 <- 0
		POP 	AF
		RET
		
;*** 1BYTE送信 ***************************************
;Aレジスタの内容をPORTA下位4BITに4BITずつ送信
SNDBYTE:
		PUSH	AF
		RRA
		RRA
		RRA
		RRA
		AND	0FH
		CALL	SND4BIT
		POP	AF
		AND	0FH
		CALL	SND4BIT
		RET

;*** 4BIT送信 ***************************************
;Aレジスタ下位4ビットを送信する
SND4BIT:
		OUT	(PPI_A),A
		LD	A,05H
		OUT	(PPI_R),A	;PORTC BIT2 <- 1
		CALL	F1CHK		;PORTC BIT7が1になるまでLOOP
		LD	A,04H
		OUT	(PPI_R),A	;PORTC BIT2 <- 0
		CALL	F2CHK
		RET

;*** BUSYをCHECK(1) ***************************************
; 82H BIT7が1になるまでLOOP
F1CHK:
		IN	A,(PPI_C)
		AND	80H		;PORTC BIT7 = 1?
		JR	Z,F1CHK
		RET

;*** BUSYをCHECK(0) ***************************************
; 82H BIT7が0になるまでLOOP
F2CHK:
		IN	A,(PPI_C)
		AND	80H		;PORTC BIT7 = 0?
		JR	NZ,F2CHK
		RET

;*** コマンド、ファイル名送信 (IN:A コマンドコード HL:ファイルネームの先頭) ****
STCMD:
		CALL	SNDBYTE		;Aレジスタのコマンドコードを送信
		CALL	RCVBYTE		;状態取得(00H=OK)
		AND	A		;00以外ならERROR
		JR	NZ,SDERR
		CALL	STFS		;ファイルネーム送信
		AND	A		;00以外ならERROR
		JR	NZ,SDERR
		RET

;*** ファイルネーム送信(IN:HL ファイルネームの先頭) ***************************************
STFS:
		PUSH	HL
		LD	D,H
		LD	E,L
		LD	B,20H
STFS1:		LD	A,(HL)		;ファイル名精査
		CP	5CH		;'\'
		JR	Z,STFS3
		CP	2FH		;'/'
		JR	Z,STFS3
		CP	3AH		;':'
		JR	Z,STFS3
		CP	2AH		;'*'
		JR	Z,STFS3
		CP	3FH		;'?'
		JR	Z,STFS3
		CP	22H		;'"'
		JR	Z,STFS3
		CP	3CH		;'<'
		JR	Z,STFS3
		CP	3EH		;'>'
		JR	Z,STFS3
		CP	7CH		;'|'
		JR	Z,STFS3		;ファイル名無効文字は削除
		AND	A
		JR	NZ,STFS2	;null以降は無視
		LD	(DE),A
		JR	STFS4
STFS2:
		CALL	AZLCNV		;ファイル名は大文字に統一
		LD	(DE),A
		INC	DE
STFS3:
		INC	HL
		DEC	B
		JR	NZ,STFS1
		INC	DE
		XOR	A
		LD	(DE),A
STFS4:
		POP	HL
		LD	B,20H
STFS5:		LD	A,(HL)		;FNAME送信
		AND	A
		JR	NZ,STFS6	;null以降は、nullを送信する
		DEC	HL
STFS6:
		CALL	SNDBYTE
		INC	HL
		DEC	B
		JR	NZ,STFS5
		LD	A,0DH
		CALL	SNDBYTE
		CALL	RCVBYTE		;状態取得(00H=OK)
		RET

;*** エラー内容表示 ***************************************
SDERR:
		PUSH	AF
		CP	0F0H
		JR	NZ,SDERR1
		LD	HL,MSGERR_F0	;SD-CARD INITIALIZE ERROR
		JR	ERRMSG
SDERR1:		CP	0F1H
		JR	NZ,SDERR2
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	MSGOUT
		LD	HL,MSGERR_F1	;File not found
		JR	ERRMSG
SDERR2:		CP	0F2H
		JR	NZ,SDERR3
		LD	HL,MSGERR_BF	;Bad file format
		JR	ERRMSG
SDERR3:		CP	0F3H
		JR	NZ,SDERR4
		LD	HL,MSGERR_MO	;Missing operand
		JR	ERRMSG
SDERR4:		CP	0F4H
		JR	NZ,SDERR5
		LD	HL,(WKBFFIL)	;ファイル名
		CALL	MSGOUT
		LD	HL,MSGERR_F4	;File exists
		JR	ERRMSG
SDERR5:		CP	0F5H
		JR	NZ,SDERR99
		LD	HL,(WKBFEND)	;ファイル名1
		CALL	MSGOUT
		LD	HL,MSGERR_F1	;File not found
		JR	ERRMSG
SDERR99:	CALL	MONBHX
		LD	A,D
		CALL	CONOUT
		LD	A,E
		CALL	CONOUT
		LD	HL,MSGERR_99	;その他ERROR
ERRMSG:		CALL	MSGOUT
		CALL	MONCLF
		POP	AF
		RET

CMDERR1:
		LD	HL,MSGERR_SE
		JR	RETBC3
CMDERR2:
		LD	HL,MSGERR_MO
		JR	RETBC3
CMDERR3:
		LD	HL,MSGERR_BF
		JR	RETBC3
CMDERR4:
		LD	HL,MSGERR_NP
		JR	RETBC3
CMDERR5:
		LD	HL,MSGERR_OM
		JR	RETBC3
CMDERR6:
		LD	HL,MSGERR_F0
		JR	RETBC3
CMDERR7:
		LD	HL,MSGERR_FC
		JR	RETBC3
CMDERR8:
		LD	HL,MSGERR_VE

;*** 終了処理 ***************************************

RETBC3:
		CALL	MSGOUT
		CALL	MONCLF
RETBC:
		RET			;BASICへ戻る

;*** BASIC分岐アドレスを行番号に戻す ***************************************
RETNUM:
		LD	HL, (BASSRT)	;先頭行セット
RETNUM1:
		LD	A, (HL)
		INC	HL
		OR	(HL)
		RET	Z		;00 00 で終了
		INC	HL
		INC	HL
		INC	HL
RETNUM2:
		CALL	ANALYS		;BASICコード解析？
		INC	A
		JR	Z,RETNUM1
		SUB	2FH
		JR	Z,RETNUM3	;(2EH + 1)なら分岐
		INC	A
		JR	NZ,RETNUM2
		PUSH	HL
		LD	HL,(LASTLB)
		INC	HL
		LD	(HL),A
		INC	HL
		LD	(HL),A
		POP	HL
		JR	RETNUM2
RETNUM3:
		DEC	HL
		DEC	HL
		DEC	HL
		LD	(HL),2FH	;「2E 分岐アドレス」 を 「2F 行番号」 に戻す
		INC	HL
		LD	A,(DE)
		INC	DE
		LD	(HL),A
		INC	HL
		LD	A,(DE)
		LD	(HL),A
		INC	HL
		JR	RETNUM2

;*** DEからの4Byteが16進数を表すアスキーコードであれば16進数に変換してHLに代入 ***
HLHEX:	LD	HL,0000H
		LD	B,04H
HLHEX1:		LD	A,(DE)
		INC	DE
		CALL	AZLCNV
		CALL	HEXCHK
		JR	C,HLHEX2
		CALL	BINCV4
		DJNZ	HLHEX1
		XOR	A
HLHEX2:		RET

;*** 16進コード・チェック ***************************************
HEXCHK:
		CP	30H
		RET	C
		CP	47H
		JR	NC,HEXCHK2
		CP	3AH
		JR	C,HEXCHK1
		CP	41H
		RET	C
HEXCHK1:	AND	A
		RET
HEXCHK2:	SCF
		RET

;*** 16進コードからバイナリ形式への変換 ***************************************
BINCV4:
		CP	3AH
		JR	C,BINCV41
		ADD	A,09H
BINCV41:	AND	0FH
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	A,L
		LD	L,A
		RET

;*** 8ビット数値から16進コードへの変換 ***************************************
MONBHX:
		PUSH	AF
		AND	0FH
		CALL	MONBHX1
		LD	E,A
		POP	AF
		AND	0F0H
		RRCA
		RRCA
		RRCA
		RRCA
		CALL	MONBHX1
		LD	D,A
		RET
MONBHX1:	CP	0AH
		JR	NC,MONBHX2
		OR	30H
		RET
MONBHX2:	ADD	A,037H
		RET

;*** 小文字->大文字変換 ***************************************
AZLCNV:
		CP	61H
		RET	C
		CP	7BH
		RET	NC
		AND	0DFH
		RET

;*** DATA ***************************************
CMDCHKSTR:
		DB	'CALL :',00H
CMDMAPCHG:
		DB	3EH,00H,0D3H,7CH,3EH,00H,0D3H,7DH,3EH,00H,0D3H,7EH,3EH,00H,0D3H,7FH,0C3H,00H,00H
MSGERR_F0:
		DB	'Device I/O error',00H
MSGERR_F1:
		DB	' is not found',00H
MSGERR_F4:
		DB	' is exists',00H
MSGERR_99:
		DB	' error',00H
MSGERR_SE:
		DB	'Syntax error',00H
MSGERR_MO:
		DB	'Missing operand',00H
MSGERR_BF:
		DB	'Bad file format',00H
MSGERR_NP:
		DB	'No program',00H
MSGERR_OM:
		DB	'Out of memory',00H
MSGERR_FC:
		DB	'Illegal function call',00H
MSGERR_VE:
		DB	'Verify error',00H
MSG_KEY:
		DB	'END=RETURN key ',00H


		END
