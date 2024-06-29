; BOOT_SSMPLE.s
;  SORD m5 メモリマッパー (+SD)用 ブート用プログラム（サンプル）
;
;  (アセンブラはZASM64使用)
;
;メモ
;(2000)=00Hの場合、(2003) のアドレスにジャンプ→(2001) のアドレスにジャンプ→(4001)=FFHでない場合、(4001) のアドレスにジャンプ
;(2000)=02Hの場合、(2003) のアドレスにジャンプ→(2001) のアドレスにジャンプ
;(2000)=FFHの場合、(4000)=FFHでない場合、(4001) のアドレスにジャンプ
;上記以外はIPLROMの処理へ


;以下のようにROMを作成（空きはFFHで埋め）しておくと、起動後にRAM+32KしてBASIC-G（+SD）を起動します
; 0000H～1FFFH 空き
; 2000H～2FFFH BOOT_SMPLE.rom
; 3000H～3FFFH 空き
; 4000H～5FFFH 空き
; 6000H～9FFFH BASIC-G（16Kバイト）
; A000H～AFFFH EXT_ROM_M5_G.rom
; B000H～最後  空き

;***************************************

EXADDR	EQU	07FF0H

	ORG	02000H

	DB	02H		;2000	02		# ROMヘッダ
	DB	00H,00H		;2001	00 00		# 実行アドレス２（未使用=RESET）
	DB	05H,20H		;2003	05 20		# 実行アドレス１（=2005H）

	XOR	A		;2005	AF		# メモリマッパー指定
	OUT	(07CH),A	;2006	D3 7C		# ページ0(0000H-3FFFH) ROM0 RESET後は必ずROM0を指定（自身なので）
	OUT	(07DH),A	;2008	D3 7D		# ページ1(4000H-7FFFH) ROM0 ページ１はとりあえずROM0で初期化する
	LD	A,020H		;200A	3E 20
	OUT	(07EH),A	;200C	D3 7E		# ページ2(8000H-BFFFH) RAM0 ページ2,3をRAMにして+32kbytes実装とする
	INC	A		;200E	3C
	OUT	(07FH),A	;200F	D3 7F		# ページ3(C000H-FFFFH) RAM1 （ただしIPLスタートしないと反映されない）


	LD	DE,EXADDR	;2011	11 F0 7F	# (ページ0を切り替えるため、PCを別のページへ移動する)
	LD	BC,0AH		;2014	01 0A 00
	LD	HL,EXCODE	;2017	21 1F 20
	LDIR			;201A	ED B8
	JP	EXADDR		;201C	C3 F0 7F
EXCODE:
	LD	A,001H		;201F	3E 01		# 以降、RAMにコピーして実行するコード
	OUT	(07CH),A	;2021	D3 7C		# ページ0(0000H-3FFFH) ROM 1
	INC	A		;2023	3C
	OUT	(07DH),A	;2024	D3 7D		# ページ1(4000H-7FFFH) ROM 2
	JP	00000H		;2026	C3 00 00	# ページ設定後、IPLスタートする

	END
