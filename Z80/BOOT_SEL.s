; BOOT_SELECTOR.s
;  SORD m5 メモリマッパー (+SD)用 ブートセレクター
;
;  (アセンブラはZASM64使用)
;
; SDのファイル一覧を表示し、指定ファイルをRAWファイルとして2000H～6FFFHにロードし再起動する
; ロード先はRAMマッパー0,1を使用（8000H～FFFFHはRAMマッパー2,3）
; 24Kバイト以上は無視する

TMODE		EQU	0D04H		;TEXTモード
CONOUT		EQU	1082H		;CRTへの1バイト出力
KYSCAN		EQU	0756H		;1文字キー入力待ち
MSGOUT		EQU	105CH		;文字列の出力
MONCLF		EQU	10EDH		;CRコード及びLFコードの表示

PPI_A		EQU	78H		;8255 IOアドレス
PPI_B		EQU	PPI_A+1
PPI_C		EQU	PPI_A+2
PPI_R		EQU	PPI_A+3

EXADDR		EQU	07B00H		;実行プログラム配置アドレス
FILENMPT	EQU	07BD0H		;ファイル名開始ポインタ（2×20ファイル）
FILECNT		EQU	07BFEH		;現在表示ファイル数
FILENAME	EQU	07C00H		;ファイル名

		ORG	02000H

		DB	02H		; ROMヘッダ
		DB	00H,00H		; 実行アドレス２（未使用=RESET）
		DB	05H,20H		; 実行アドレス１（=2005H）

		XOR	A		; メモリマッパー初期化
		OUT	(07CH),A	; ページ0(0000H-3FFFH) ROM0 RESET後は必ずROM0を指定（自身なので）
		OUT	(07DH),A	; ページ1(4000H-7FFFH) ROM0 とりあえず設定（未使用）
		LD	A,20H
		OUT	(07EH),A	; ページ2(8000H-BFFFH) RAM0 ページ2,3はRAM0,1にする
		INC	A
		OUT	(07FH),A	; ページ3(C000H-FFFFH) RAM1


		CALL	TMODE

		LD	HL,MSG_TITLE
		CALL	MSGOUT		;タイトル表示
WAIT:
		CALL	INIT		;8255を初期化
		CALL	IOCHK		;MSX_SDチェック
		CP	0FFH
		JP	Z,WAIT		;IOエラー
LOOP:
		LD	A,83H		;コマンド83Hを送信
		LD	HL,DUMMYNAME	;ファイル名
		CALL	STCMD
		JP	NZ,END		;エラー	
FILES0:
		CALL	MONCLF
		CALL	MONCLF
		LD	A,41H
		LD	(FILECNT),A	;ファイルカウント初期化
		LD	DE,FILENMPT	;ファイル名格納アドレス
		LD	HL,FILENAME	;ファイル名格納バッファ先頭アドレス
FILES1:
		LD	A,L
		LD	(DE),A
		INC	DE
		LD	A,H
		LD	(DE),A
		INC	DE
		LD	A,(FILECNT)
		LD	(HL),A
		INC	A
		LD	(FILECNT),A
		INC	HL
FILES2:
		CALL	RCVBYTE
		AND	A
		JR	Z,FILES3	;'00H'を受信したら一行分を表示して改行
		CP	0FFH
		JR	Z,FILES4	;'0FFH'を受信したら終了
		CP	0FEH
		JR	Z,FILES7	;'0FEH'を受信したら一時停止して一文字入力待ち
		LD	(HL),A
		INC	HL
		JR	FILES2
FILES3:
		LD	(HL),A
		INC	HL
		PUSH	HL
		PUSH	DE
		EX	DE,HL
		DEC	HL
		LD	D,(HL)
		DEC	HL
		LD	E,(HL)
		EX	DE,HL
		CALL	MSGOUT
		POP	DE
		POP	HL
		JR	FILES1
FILES4:
		CALL	RCVBYTE		;状態取得(00H=OK)

		LD	A,(FILECNT)
		DEC	A
		DEC	A
		CALL	PAUSE
FILES5:
		CALL	KYSCAN		;1文字入力待ち
		CALL	AZLCNV
		AND	A
		JR	Z,FILES5
		CP	41H
		JR	C,FILES6
		LD	BC,(FILECNT)
		DEC	C
		CP	C
		JR	C,LOAD1
FILES6:
		JP	LOOP
PAUSE:
		PUSH	AF
		CALL	MONCLF
		LD	HL,MSG_KEY1	;pauseプロンプト表示
		CALL	MSGOUT
		POP	AF
		CALL	CONOUT
		LD	HL,MSG_KEY2
		CALL	MSGOUT
		RET
FILES7:
		LD	A,54H
		CALL	PAUSE
FILES8:
		CALL	KYSCAN		;1文字入力待ち
		CALL	AZLCNV
		AND	A
		JR	Z,FILES8
		CP	41H
		JR	C,FILES9
		LD	BC,(FILECNT)
		DEC	C
		CP	C
		JR	C,FILES10
FILES9:
		XOR	A		;それ以外で継続
		CALL	SNDBYTE
		JP	FILES0
FILES10:
		LD	B,A
		LD	A,0FFH		;0FFH中断コードを送信
		CALL	SNDBYTE
		CALL	RCVBYTE		;取得(FFH)
		CALL	RCVBYTE		;状態取得(00H=OK)
		LD	A,B
LOAD1:
		SUB	41H
		RLCA

		LD	HL,FILENMPT	;ファイル名格納アドレス
		LD	B,00H
		LD	C,A
		ADD	HL,BC
		LD	E,(HL)
		INC	HL
		LD	D,(HL)
		EX	DE,HL		;ファイル名先頭
		LD	BC,0007H
		ADD	HL,BC

		PUSH	HL
		PUSH	HL
		CALL	MONCLF
		LD	HL,MSG_LOAD	;ロード中表示
		CALL	MSGOUT
		POP	HL
		CALL	MSGOUT
		POP	HL

		LD	A,72H		;コマンド72Hを送信
		CALL	STCMD
		JP	NZ,END		;エラー

		LD	HL,0A000H	;ロードアドレス設定
		LD	DE,0EFFFH	;使用可能最終アドレス
LOAD2:
		CALL	RCVBYTE		;データ長
		AND	A
		JR	Z,EXECUTE	;データ長が0なら終了
		LD	B,A
LOAD3:
		CALL	RCVBYTE		;実データ
		LD	(HL),A

		PUSH	HL
		SBC	HL,DE
		POP	HL
		JR	Z,LOAD4		;使用可能まで達したら空読みモード

		INC	HL
		DJNZ	LOAD3
		JR	LOAD2

LOAD4:					;空読みモード
		DJNZ	LOAD6
LOAD5:
		CALL	RCVBYTE		;データ長
		AND	A
		JR	Z,EXECUTE	;データ長が0なら終了
		LD	B,A
LOAD6:
		CALL	RCVBYTE		;実データ
		DJNZ	LOAD6
		JR	LOAD5


EXECUTE:
		LD	DE,EXADDR	; (ページ0を切り替えるため、PCを別のページへ移動する)
		LD	BC,EXCODEEND-EXCODE
		LD	HL,EXCODE
		LDIR
		JP	EXADDR
EXCODE:
		LD	A,20H		; 以降、RAMにコピーして実行するコード
		OUT	(07CH),A	; ページ0(0000H-3FFFH) RAM 0
		INC	A
		OUT	(07DH),A	; ページ1(4000H-7FFFH) RAM 1
		INC	A
		OUT	(07EH),A	; ページ1(8000H-BFFFH) RAM 2
		INC	A
		OUT	(07FH),A	; ページ1(C000H-FFFFH) RAM 3
		RST	00H		; ページ設定後、IPLスタートする
EXCODEEND:


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
		JR	Z,STFS3
		CP	0DH		;CR
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
		JR	NZ,SDERR99
		LD	HL,MSGERR_F1	;File not found
		JR	ERRMSG
SDERR99:	CALL	MONBHX
		LD	A,D
		CALL	CONOUT
		LD	A,E
		CALL	CONOUT
		LD	HL,MSGERR_99	;その他ERROR
ERRMSG:		CALL	MSGOUT
		POP	AF
		RET

END:
		IM	0
		DI
		HALT


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

MSGERR_F0:
		DB	'Device I/O error',0DH,00H
MSGERR_F1:
		DB	'File not found',0DH,00H
MSGERR_99:
		DB	' error',0DH,00H
MSG_TITLE:
		DB	'M5MMSD Boot Selector',00H
MSG_LOAD:
		DB	'Loading ',00H
MSG_KEY1:
		DB	'Load select from A-',00H
MSG_KEY2:
		DB	', next page other'
DUMMYNAME:
		DB	00H

		END
