; "DIGITAL CLOCK"          
; (C) BOUROUHOU AYOUB ENSA KHOURIBGA GENIE ELECTRIQUE ELECTRONIQUE NUMERIQUE, DECEMBRE 2022

; version 1.0.5 : modification suite à une extension
; du circuit avec 60 leds 

; microcontrôleur PIC 16F84A
; développé avec Microchip MPLAB IDE 8.10

	List p=16F84A	; processeur utilisé 
	#include <p16F84A.inc>

	__config _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
		;bits de configuration :
		;code protect OFF
		;watchdog timer OFF
		;power up timer ON
		;oscillateur HS (quartz 20 MHz)
  
;xxxxxx
; macro
;xxxxxx

bank1	macro		; passage en banque 1
		bsf STATUS,RP0 
		endm
bank0	macro		; passage en banque 0
		bcf STATUS,RP0
		endm

;xxxxxxxxxxxxxxxxxxxxxxxxx
; déclaration de variables
;xxxxxxxxxxxxxxxxxxxxxxxxx

	CBLOCK H'00C'		; début de la zone des registres d'usage général du 16F84A

	digit :	1			; variable qui indique n° de l'afficheur actif (1 à 4)
	STATUS_TEMP : 1 	; sauvegarde du registre STATUS (routine d'interruption)
	W_TEMP : 1 			; sauvegarde du registre W		(routine d'interruption)
	afficheur_1 : 1		; contient le chiffre des heures (dizaines) à afficher (codage BCD)
	afficheur_2 : 1		; contient le chiffre des heures (unités) à afficher (codage BCD)
	afficheur_3 : 1		; contient le chiffre des minutes (dizaines) à afficher (codage BCD)
	afficheur_4 : 1		; contient le chiffre des minutes (unités) à afficher (codage BCD)
	afficheur : 1		; contient le chiffre actif à afficher (codage BCD)
	flag_tempo_heure : 1	; drapeau mis à 1 au début de la temporisation anti-rebonds
						; du bouton poussoir HEURE (on utilise le bit 0)
	flag_tempo_minute : 1	; drapeau mis à 1 au début de la temporisation anti-rebonds
							; du bouton poussoir MINUTE (on utilise le bit 0)
	compteur_tempo_minute : 1 ; compteur de la temporisation anti-rebonds
						; du bouton poussoir MINUTE (on utilise le bit 0)
	compteur_tempo_heure : 1 ; compteur de la temporisation anti-rebonds
						; du bouton poussoir HEURE (on utilise le bit 0)
	compteur : 1		; compteur des 1/256 de seconde
	secondes : 1 		; compteur de secondes

	ENDC 

;xxxxxxxxxxxxxxxxxxxx
; démarrage sur reset
;xxxxxxxxxxxxxxxxxxxx

	org H'0000'
	goto initialisation

; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine d'interruption 
; 1 source d'interruption
; - TMR0 en mode compteur (broche RA4/T0CKI)
; Cette interruption a lieu toutes les 1/256 seconde exactement
; (quartz 32768 Hz prescaler 1:1 -> 1/128 seconde :
; durée divisée par 2 en ajoutant 128 au TMR0)
; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

	org H'0004'	 			; vecteur d'interruption

	movwf W_TEMP 
	swapf STATUS,W
	movwf STATUS_TEMP		; sauvegarde du registre W puis du registre STATUS

	movlw D'128'
	addwf TMR0,f			; on augmente le TMR0 de D'128'
	
	call BP_minute    ; routine de gestion du bouton poussoir REGLAGE MINUTE
	call BP_heure     ; routine de gestion du bouton poussoir REGLAGE HEURE

	movlw D'128'
	subwf compteur,W
	btfsc STATUS,Z 			
 	bsf PORTB,6				; compteur = 128 : on éteint les segments DP	

	incf compteur,f	; on incrémente le compteur des 1/256 seconde
	movf compteur,f
	btfss STATUS,Z 			; compteur = 0 ?
	goto raf				; non	
	bcf PORTB,6				; oui : on allume les segments DP
	incf secondes,f			; la seconde est atteinte : on incrémente
	movlw D'60'
	subwf secondes,W
	btfss STATUS,Z 		
	goto raf
	clrf secondes			; la minute est atteinte : on incrémente	

	bcf PORTB , 7		; RB7 = 0 (impulsion niveau bas)
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bsf PORTB , 7		; RB7 = 1 (fin de l'impulsion)

	call heure_minute_plus		; mise à jour de l'heure
	
raf
	call rafraichissement

	bcf INTCON,T0IF			; on efface le drapeau T0IF	
	goto restauration

restauration

	swapf STATUS_TEMP,W		; restauration des registres STATUS puis W
	movwf STATUS	
	swapf W_TEMP,f
	swapf W_TEMP,W

	retfie		  			; retour d'interruption

; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine de rafraîchissement de l'affichage
; Les 4 afficheurs sont multiplexés
; On active les afficheurs les uns après les autres (un toutes les 1/256 s)

rafraichissement
	
	decf digit, f		; on change d'afficheur 4->3->2->1->4-> etc
	btfss STATUS, Z
	goto suite
	movlw D'4'
	movwf digit
suite

	; on alimente l'afficheur correspondant
	movlw D'1'
	subwf digit, W
	btfss STATUS, Z
	goto digit2			; (digit) différent de 1
	movlw B'00001110'
	movwf PORTA			; RA0=0 : afficheur1 alimenté
	movf afficheur_1, W
	movwf afficheur		; on charge (afficheur_1) dans (afficheur)
	goto fin

digit2

	movlw D'2'
	subwf digit, W
	btfss STATUS, Z
	goto digit3			; (digit) différent de 2
	movlw B'00001101'
	movwf PORTA			; RA1=0 : afficheur2 alimenté 
	movf afficheur_2, W
	movwf afficheur		; on charge (afficheur_2) dans (afficheur)
	goto fin	
	
digit3

	movlw D'3'
	subwf digit, W
	btfss STATUS, Z
	goto digit4			; (digit) différent de 3
	movlw B'00001011'
	movwf PORTA			; RA2=0 : afficheur3 alimenté 
	movf afficheur_3, W
	movwf afficheur		; on charge (afficheur_3) dans (afficheur)
	goto fin

digit4

	movlw D'4'
	subwf digit, W
	btfss STATUS, Z
	goto fin			; (digit) différent de 4 
	movlw B'00000111'
	movwf PORTA			; RA3=0 : afficheur4 alimenté 
	movf afficheur_4, W
	movwf afficheur		; on charge (afficheur_4) dans (afficheur)
	goto fin

fin

; commande de l'afficheur actif

	movlw D'0'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur1			; (afficheur) différent de 0
	bcf PORTB, 2
	bcf PORTB, 3
	bcf PORTB, 4
	bcf PORTB, 5			; on affiche 0
	return

valeur1 
	movlw D'1'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur2			; (afficheur) différent de 1
	bsf PORTB, 2
	bcf PORTB, 3
	bcf PORTB, 4
	bcf PORTB, 5			; on affiche 1
	return

valeur2
	movlw D'2'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur3			; (afficheur) différent de 2
	bcf PORTB, 2
	bsf PORTB, 3
	bcf PORTB, 4
	bcf PORTB, 5			; on affiche 2
	return

valeur3
	movlw D'3'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur4			; (afficheur) différent de 3
	bsf PORTB, 2
	bsf PORTB, 3
	bcf PORTB, 4
	bcf PORTB, 5			; on affiche 3
	return

valeur4
	movlw D'4'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur5			; (afficheur) différent de 4
	bcf PORTB, 2
	bcf PORTB, 3
	bsf PORTB, 4
	bcf PORTB, 5			; on affiche 4
	return

valeur5
	movlw D'5'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur6			; (afficheur) différent de 5
	bsf PORTB, 2
	bcf PORTB, 3
	bsf PORTB, 4
	bcf PORTB, 5			; on affiche 5
	return

valeur6
	movlw D'6'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur7			; (afficheur) différent de 6
	bcf PORTB, 2
	bsf PORTB, 3
	bsf PORTB, 4
	bcf PORTB, 5			; on affiche 6
	return

valeur7
	movlw D'7'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur8			; (afficheur) différent de 7
	bsf PORTB, 2
	bsf PORTB, 3
	bsf PORTB, 4
	bcf PORTB, 5			; on affiche 7
	return

valeur8
	movlw D'8'
	subwf afficheur, W
	btfss STATUS, Z
	goto valeur9			; (afficheur) différent de 8
	bcf PORTB, 2
	bcf PORTB, 3
	bcf PORTB, 4
	bsf PORTB, 5			; on affiche 8
	return

valeur9
	movlw D'9'
	subwf afficheur, W
	btfss STATUS, Z
	return					;  (par précaution)
	bsf PORTB, 2
	bcf PORTB, 3
	bcf PORTB, 4
	bsf PORTB, 5			; on affiche 9
	return


; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine de gestion du bouton poussoir REGLAGE MINUTE (broche RB0)
; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BP_minute    
	;test du flag_tempo_minute
	btfsc flag_tempo_minute, 0
	goto flag_tempo_minute_1
	; flag_tempo_minute = 0	
	btfsc PORTB,0	
	return		; BP au repos
	; BP appuyé
	bsf flag_tempo_minute, 0	; drapeau mis à 1
	movlw D'50'                 ; temporisation de 50/256 # 200 ms
	movwf compteur_tempo_minute
	return

flag_tempo_minute_1 ; le flag_tempo_minute est égal à 1
	decf compteur_tempo_minute,f
	btfss STATUS, Z
	return		; le compteur n'est pas nul	
	; le compteur est nul
	bcf flag_tempo_minute, 0	; drapeau mis à 0
	call minute_plus			
	return

; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine de gestion du bouton poussoir REGLAGE HEURE (broche RB1)
; xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BP_heure    
	;test du flag_tempo_heure
	btfsc flag_tempo_heure, 0
	goto flag_tempo_heure_1
	; flag_tempo_heure = 0	
	btfsc PORTB,1	
	return		; BP au repos
	; BP appuyé
	bsf flag_tempo_heure, 0		; drapeau mis à 1
	movlw D'50'                 ; temporisation de 50/256 # 200 ms
	movwf compteur_tempo_heure
	return

flag_tempo_heure_1 ; le flag_tempo_minute est égal à 1
	decf compteur_tempo_heure,f
	btfss STATUS, Z
	return		; le compteur n'est pas nul	
	; le compteur est nul
	bcf flag_tempo_heure, 0	; drapeau mis à 0
	call heure_plus			
	return

;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine "heure_minute_plus"
; Incrémentation d'une minute de l'heure courante
; afficheur_4 -> minute (unité)
; afficheur_3 -> minute (dizaine)
; afficheur_1 -> heure (unité)
; afficheur_2 -> heure (dizaine)
; 10:00->10:01-> ... ->10:59->11:00->11:01 ...->23:59->00:00
;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine "heure_plus"
; Incrémentation d'une heure (appuie sur BP "REGLAGE HEURE")
; afficheur_1 -> heure (unité)
; afficheur_2 -> heure (dizaine)
; 10->11-> ... ->23->00->01 ...
;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

heure_minute_plus

	incf afficheur_4,f
 	; on teste si (afficheur_4)=D'10'
	movlw D'10'
	subwf afficheur_4,W
	btfss STATUS,Z 		
	return		; (afficheur_4) différent (inférieur à) de D'10'
	; (afficheur_4) égal à D'10'
	clrf afficheur_4
	incf afficheur_3,f	
	; on teste si (afficheur_3)=D'6'
	movlw D'6'
	subwf afficheur_3,W
	btfss STATUS,Z 		
	return		; (afficheur_3) différent de D'6'
	; (afficheur_3) égal à D'6'
	clrf afficheur_3

heure_plus
	; on teste s'il est 23 heures
	movlw D'3'
	subwf afficheur_2,W
	btfss STATUS,Z 		
	goto not23
	movlw D'2'
	subwf afficheur_1,W
	btfss STATUS,Z 		
	goto not23
	; il est 23 heures donc on passe à 00 heure
	clrf afficheur_2
	clrf afficheur_1
	return

not23	
	incf afficheur_2,f	
	; on teste si (afficheur_2)=D'10'
	movlw D'10'
	subwf afficheur_2,W
	btfss STATUS,Z 		
	return		; (afficheur_2) différent de D'10'
	; (afficheur_2) égal à D'10'
	clrf afficheur_2
	incf afficheur_1,f	
	return

;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; Routine "minute_plus"
; Incrémentation d'une minute (appuie sur BP "REGLAGE MINUTE")
; afficheur_4 -> minute (unité)
; afficheur_3 -> minute (dizaine)
; 00->01->02 ... ->59->00->01 ...
;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

minute_plus

	incf afficheur_4,f
 	; on teste si (afficheur_4)=D'10'
	movlw D'10'
	subwf afficheur_4,W
	btfss STATUS,Z 		
	return		; (afficheur_4) différent (inférieur à) de D'10'
	; (afficheur_4) égal à D'10'
	clrf afficheur_4
	incf afficheur_3,f	
	; on teste si (afficheur_3)=D'6'
	movlw D'6'
	subwf afficheur_3,W
	btfss STATUS,Z 		
	return		; (afficheur_3) différent de D'6'
	; (afficheur_3) égal à D'6'
	clrf afficheur_3
	return


;xxxxxxxxxxxxxxx
; initialisation
;xxxxxxxxxxxxxxx

initialisation   

	bank0	
	clrf PORTA  	; mise à 0 des sorties du port A
	clrf PORTB 		; mise à 0 des sorties du port B
	
	bank1
	movlw B'00101000'
	movwf OPTION_REG
	; bit 7 (/RBPU) = 0 : activation des résistances de pull-up du port B
	; bit 6 (INTEDG)= 0 : (non utilisée)
	; bit 5 (T0CS) = 1 : TMR0 Clock Source Select = RA4/T0CKI (mode compteur)
	; bit 4 (T0SE) = 0 :  RA4/T0CKI actif sur front montant
	; bit 3 (PSA) = 1  : Prescaler attribué au Watchdog
	; bit 2 (PS2)= 0	  
	; bit 1 (PS1) = 0 
	; bit 0 (PS0) = 0 : Facteur de division du prescaler = 1:1

	movlw B'00010000' 
	movwf TRISA
	; bit 0 du port A (RA0) = 0 : configuration en sortie (afficheur 1)
	; bit 1 du port A (RA1) = 0 : configuration en sortie (afficheur 2)
	; bit 2 du port A (RA2) = 0 : configuration en sortie (afficheur 3)
	; bit 3 du port A (RA3) = 0 : configuration en sortie (afficheur 4)
	; bit 4 du port A (RA4) = 1 : configuration en entrée (quartz 32768 Hz)

	movlw B'00000011'
	movwf TRISB
	; bit 0 du port B (RB0) = 1 : configuration en entrée (bouton poussoir REGLAGE MINUTE) 
	; bit 1 du port B (RB1) = 1 : configuration en entrée (bouton poussoir REGLAGE HEURE) 
	; bit 2 du port B (RB2) = 0 : configuration en sortie (entrée A du 7447)
	; bit 3 du port B (RB3) = 0 : configuration en sortie (entrée B du 7447)
	; bit 4 du port B (RB4) = 0 : configuration en sortie (entrée C du 7447)
	; bit 5 du port B (RB5) = 0 : configuration en sortie (entrée D du 7447)
	; bit 6 du port B (RB6) = 0 : configuration en sortie (segments DP)
	; bit 7 du port B (RB7) = 0 : configuration en sortie (impulsion au niveau bas chaque minute)

	bank0
	movlw B'10100000' 
	movwf INTCON
	; bit 7 (GIE) = 1 : autorisation globale des interruptions
	; bit 5 (T0IE) = 1 : autorisation de l'interruption TMR0
	; bit 2 (T0IF)= 0 : on efface le drapeau de l'interruption TMR0
	; les autres bits sont inutilisés (valeur par défaut = 0)	

	clrf PORTA		; sorties du port A au niveau bas
					; les afficheurs sont donc éteints
	
	bcf PORTB , 7		; RB7 = 0 (impulsion niveau bas)
	clrf TMR0			; mise à zero du timer0
	clrf afficheur_1	
	clrf afficheur_2
	clrf afficheur_3
	clrf afficheur_4
	clrf afficheur
	clrf compteur
	clrf secondes
	movlw D'4'
	movwf digit
	clrf flag_tempo_minute
	clrf flag_tempo_heure		
	movlw D'50'	
	movwf compteur_tempo_minute
	movwf compteur_tempo_heure
	bsf PORTB , 7		; RB7 = 1 (fin de l'impulsion)

	goto debut_programme  
		
;xxxxxxxxxxxxxxxxxxxxx 
; programme principal
;xxxxxxxxxxxxxxxxxxxxx

debut_programme 

; on attend le débordement de TMR0 (H'FF' -> H'00')
; ce qui génére une interruption toutes les 1/256 s

	goto debut_programme    

	END
