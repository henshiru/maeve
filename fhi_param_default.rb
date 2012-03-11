# 東大アップリンクはRubyなので Math::sqrtなども使えるが
# FHIプログラムでの初期読込では乗算のみ対応で、+-/すら未実装なので
# 乗算のみで設定する事。
# ゲイン設定は100カラムを超えないこと。
# 超える場合はFHI_mainのChbuf[100]を増やすこと。
# [ の前までの順番は変更可。2回以上の設定は下の値に上書きされる。
# ゲイン設定日時 2011.1.20 17:17

    KItheta         = 0.2592            #00 PID KthetaI
    Ktheta          = 0.1536            #01 PID Ktheta
    Kq_theta        = 0.0090            #02 PID Kq_theta
    KIphi           = 0.6487            #03 PID KphiI
    Kphi            = 0.1058            #04 PID Kphi
    Kdp             = 0.0018            #05 PID Kp
    KBdot           = 0.3656 * 0.25     #06 PID KBdot
    KAy             = 0.0000            #07 PID KAy
    KIAy            = 0.0920            #08 PID KAyI
    fflag_DINN      = 1                 #09 1=>DI+NN 0=> PID
    dKomegaPhi      = 9.26 * 0.65       #10 DI dKPhi   ωr  = 32.4rad/s 9.26rad/s?
    dKomegaTheta    = 9.47 * 0.4 * 1.2  #11 DI dKTheta ωsp = 26.1rad/s 9.47rad/s?
    dKomegaBeta     = 5.32 * 0.1 * 5.0  #12 DI dKBeta  ωnd = 10.1rad/s 5.32rad/s?
    dZetaPhi        = 1.0               #13 DI ζPhi
    dZetaTheta      = 1.0               #14 DI ζTheta
    dZetaBeta       = 1.0               #15 DI ζBeta 
    dNN_Gamma_W     = 0.02              #23 NN GAMMA_W 出力側学習ゲイン
    dNN_Gamma_V     = 0.7               #24 NN GAMMA_V 入力側学習ゲイン
    dNN_Kr0         = 0.01              #25 Kr0 ロバスト項 Org

    dKP_EAS         = 12    #*1.5       #26 EAS Kp
    dKI_EAS         = 0.06  #*0.7       #27 EAS KI

    dBW             = 1.0#0.2           #28 NN出力側バイアス項dBW
    dBV             = 1.0#0.8           #29 NN入力側バイアス項dBV
    dNNlambda       = 0.5               #20 NN lambda

    dNN_KomegaPhi   = dKomegaPhi        #16 NN dKPhi 
    dNN_KomegaTheta = dKomegaTheta      #17 NN dKTheta
    dNN_KomegaBeta  = dKomegaBeta       #18 NN dKBeta
    dNN_ZetaPhi     = dZetaPhi          #19 NN zeta Phi
    dNN_ZetaTheta   = dZetaTheta        #21 NN zeta Theta
    dNN_ZetaBeta    = dZetaBeta         #22 NN zeta Beta

#    dCGSTA	        = 686.4             #30 CGSTA[mm] +20mm
    dCGSTA	        = 666.4             #30 CGSTA[mm] Nominal
#    dCGSTA	        = 626.4             #30 CGSTA[mm] -40mm
#    dCGSTA	        = 646.4             #30 CGSTA[mm] -20mm
#    dCGSTA	        = 616.4             #30 CGSTA[mm] -50mm
    dCGBL	        = 0.0               #31 CGBL[mm]
    dCGWL	        = 0.0               #32 CGWL[mm]
    #    dIxx	        =  0.0781            #33 Ixx[kgm2] 製造時計測値
    #    dIyy	        =  0.234             #34 Iyy[kgm2] 製造時計測値
    #    dIzz	        =  0.287             #35 Izz[kgm2] 製造時計測値
    #    dIxz           =  0.0660            #36 Ixz[kgm2] 製造時計測値
    dIxx	        = 0.133             #33 Ixx[kgm2] 推算値
    dIyy	        = 0.342             #34 Iyy[kgm2] 推算値
    dIzz	        = 0.433             #35 Izz[kgm2] 推算値
    dIxz            = 0.065             #36 Ixz[kgm2] 推算値
    dWeight         = 3.02              #37 weight[kg] 計測値@大樹町
    fNNflag         = 1.0               #38 NNflag 0:DI単体, 1:DI+NN
[
    KItheta,        #00 PID KthetaI
    Ktheta,         #01 PID Ktheta
    Kq_theta,       #02 PID Kq_theta
    KIphi,          #03 PID KphiI
    Kphi,           #04 PID Kphi
    Kdp,            #05 PID Kp
    KBdot,          #06 PID KBdot
    KAy,            #07 PID KAy
    KIAy,           #08 PID KAyI
    fflag_DINN,     #09 1=>DI+NN 0=> PID
    dKomegaPhi,     #10 DI dKPhi 
    dKomegaTheta,   #11 DI dKTheta
    dKomegaBeta,    #12 DI dKBeta
    dZetaPhi,       #13 DI zeta Phi
    dZetaTheta,     #14 DI zeta Theta
    dZetaBeta,      #15 DI zeta Beta
    dNN_KomegaPhi,  #16 NN dKPhi 
    dNN_KomegaTheta,#17 NN dKTheta
    dNN_KomegaBeta, #18 NN dKBeta
    dNN_ZetaPhi,    #19 NN zeta Phi
    dNNlambda,      #20 ramda
    dNN_ZetaTheta,  #21 NN zeta Theta
    dNN_ZetaBeta,   #22 NN zeta Beta
    dNN_Gamma_W,    #23 NN GAMMA_W
    dNN_Gamma_V,    #24 NN GAMMA_V
    dNN_Kr0,        #25 Kr0
    dKP_EAS,        #26 EAS Kp
    dKI_EAS,        #27 EAS KI
    dBW,            #28 dBW
    dBV,            #29 dBV
    dCGSTA,         #30 CGSTA[mm]
    dCGBL,          #31 CGBL[mm]
    dCGWL,          #32 CGWL[mm]
    dIxx,           #33 Ixx[kgm2]
    dIyy,           #34 Iyy[kgm2]
    dIzz,           #35 Izz[kgm2]
    dIxz,           #36 Ixz[kgm2]
    dWeight,        #37 weight[kg]
    fNNflag         #38 NNflag 0:DI単体, 1:DI+NN
]

