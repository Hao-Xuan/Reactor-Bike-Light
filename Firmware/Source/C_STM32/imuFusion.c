/*
 * imuFusion.c
 *
 *  Created on: Oct 13, 2025
 *      Author: drkNRG
 */

#include "main.h"
#include "imuFusion.h"

// public variables
	float DELTA_T;
// private functions
// compile Kalman filter inputs from sensor data
static void imuFusion_get_inputs(IMUfusion_handler_t *imuFusion, int16_t *imu_data) {
	//copy IMU data
	imuFusion->IN.A[0] = (float)imu_data[0] / IMU_SCALE_A;
	imuFusion->IN.A[1] = (float)imu_data[1] / IMU_SCALE_A;
	imuFusion->IN.A[2] = (float)imu_data[2] / IMU_SCALE_A;
	imuFusion->IN.W[0] = ((float)imu_data[3] / IMU_SCALE_G) * DEG_TO_RAD;
	imuFusion->IN.W[1] = ((float)imu_data[4] / IMU_SCALE_G) * DEG_TO_RAD;
	imuFusion->IN.W[2] = ((float)imu_data[5] / IMU_SCALE_G) * DEG_TO_RAD;
	// compute static attitude measurement from previous yaw estimate and accelerometer data
	float gx_perp = sqrtf(powf(imuFusion->IN.A[1], 2.0) + powf(imuFusion->IN.A[2], 2.0));
	float gy_perp = sqrtf(powf(imuFusion->IN.A[0], 2.0) + powf(imuFusion->IN.A[2], 2.0));
	float m[3];
	m[0] = 0.5 * (imuFusion->OUT.e[0] + imuFusion->IN.W[2] * DELTA_T);
	m[1] = 0.5 * atan2f(imuFusion->IN.A[0], gx_perp);
	m[2] = 0.5 * atan2f(imuFusion->IN.A[1], gy_perp);
	// convert Euler angle measurements to Euler parameters
	float cosY_2 = cosf(m[0]);
	float sinY_2 = sinf(m[0]);
	float cosP_2 = cosf(m[1]);
	float sinP_2 = sinf(m[1]);
	float cosR_2 = cosf(m[2]);
	float sinR_2 = sinf(m[2]);
	imuFusion->EPKF.z[0] = cosR_2 * cosP_2 * cosY_2 + sinR_2 * sinP_2 * sinY_2;
	imuFusion->EPKF.z[1] = sinR_2 * cosP_2 * cosY_2 - cosR_2 * sinP_2 * sinY_2;
	imuFusion->EPKF.z[2] = cosR_2 * sinP_2 * cosY_2 + sinR_2 * cosP_2 * sinY_2;
	imuFusion->EPKF.z[3] = cosR_2 * cosP_2 * sinY_2 - sinR_2 * sinP_2 * cosY_2;
}
// compile sensor fusion outputs from Kalman filter result
static void imuFusion_set_outputs(IMUfusion_handler_t *imuFusion) {
	// convert Euler parameter estimates to Euler angles
	float sinYcosP = 2.0 * (imuFusion->EPKF.x[0] * imuFusion->EPKF.x[3] + imuFusion->EPKF.x[1] * imuFusion->EPKF.x[2]);
	float cosYcosP = 1.0 - 2.0 * (powf(imuFusion->EPKF.x[2], 2.0) + powf(imuFusion->EPKF.x[3], 2.0));
	float sinP = sqrtf(1.0 + 2.0 * (imuFusion->EPKF.x[0] * imuFusion->EPKF.x[2] - imuFusion->EPKF.x[1] * imuFusion->EPKF.x[3]));
	float cosP = sqrtf(1.0 - 2.0 * (imuFusion->EPKF.x[0] * imuFusion->EPKF.x[2] - imuFusion->EPKF.x[1] * imuFusion->EPKF.x[3]));
	float sinRcosP = 2.0 * (imuFusion->EPKF.x[0] * imuFusion->EPKF.x[1] + imuFusion->EPKF.x[2] * imuFusion->EPKF.x[3]);
	float cosRcosP = 1.0 - 2.0 * (powf(imuFusion->EPKF.x[1], 2.0) + powf(imuFusion->EPKF.x[2], 2.0));
	imuFusion->OUT.e[0] = atan2f(sinYcosP, cosYcosP);
	imuFusion->OUT.e[1] = 2.0 * atan2f(sinP, cosP) - M_PI_2;
	imuFusion->OUT.e[2] = atan2f(sinRcosP, cosRcosP);
	// calculate acceleration and velocity estimates
	float g[3];
	g[0] = sinf(imuFusion->OUT.e[1]);
	g[1] = sinf(imuFusion->OUT.e[2]);
	g[2] = cosf(imuFusion->OUT.e[1]) * cosf(imuFusion->OUT.e[2]);
	for (int i = 0; i < 3; i ++) {
		imuFusion->OUT.a[i] = imuFusion->IN.A[i] - g[i];
		imuFusion->OUT.v[i] += imuFusion->OUT.a[i] * DELTA_T;
		imuFusion->OUT.w[i] = imuFusion->IN.W[i];
	}
}
// execute Kalman filter algorithm
static void imuFusion_Process_Euler_KF(IMUfusion_handler_t *imuFusion) {
	// compute state transition matrix from gyroscope data
	imuFusion->EPKF.A[0][0] = imuFusion->EPKF.A[1][1] = imuFusion->EPKF.A[2][2] = imuFusion->EPKF.A[3][3] = 1.0;
	imuFusion->EPKF.A[1][0] = imuFusion->EPKF.A[2][3] = 0.5 * DELTA_T * imuFusion->IN.W[0];
	imuFusion->EPKF.A[0][1] = imuFusion->EPKF.A[3][2] = -0.5 * DELTA_T * imuFusion->IN.W[0];
	imuFusion->EPKF.A[2][0] = imuFusion->EPKF.A[3][1] = 0.5 * DELTA_T * imuFusion->IN.W[1];
	imuFusion->EPKF.A[0][2] = imuFusion->EPKF.A[1][3] = -0.5 * DELTA_T * imuFusion->IN.W[1];
	imuFusion->EPKF.A[3][0] = imuFusion->EPKF.A[1][2] = 0.5 * DELTA_T * imuFusion->IN.W[2];
	imuFusion->EPKF.A[0][3] = imuFusion->EPKF.A[2][1] = -0.5 * DELTA_T * imuFusion->IN.W[2];
	// compute state prediction: xp_i(4) = A_ij * x_j, sum j
	float xp[4];
	for (int i = 0; i < 4; i ++) {
		xp[i] = 0.0;
		for (int j = 0; j < 4; j ++) {
			xp[i] += imuFusion->EPKF.A[i][j] * imuFusion->EPKF.x[j];
		}
	}
	// compute co-variance prediction: Pp_ij(4x4) = Q_ij + A_ik * P_kl * AT_lj, sum k
	//											  = Q_ij + AP_il * A_jl, sum l
	float AP[4][4];
	for (int i = 0; i < 4; i ++) {
		for (int l = 0; l < 4; l ++) {
			AP[i][l] = 0.0;
			for (int k = 0; k < 4; k ++) {
				AP[i][l] += imuFusion->EPKF.A[i][k] * imuFusion->EPKF.P[k][l];}
		}
	}
	float Pp[4][4];
	float APAT[4][4];
	for (int i = 0; i < 4; i ++) {
		for (int j = 0; j < 4; j ++) {
			APAT[i][j] = 0.0;
			for (int l = 0; l < 4; l ++) {
				APAT[i][j] += AP[i][l] * imuFusion->EPKF.A[j][l];
			}
			Pp[i][j] = imuFusion->EPKF.Q[i][j] + APAT[i][j];
		}
	}
	//compute innovation co-variance inverse: SI(4x4) = (Pp + R)^-1
	float S[4][4];
	for (int i = 0; i < 4; i ++) {
		for (int j = 0; j < 4; j ++) {
			S[i][j] = Pp[i][j] + imuFusion->EPKF.R[i][j];
		}
	}
	float Sm[4][4];
	float s[3][3];
	for (int i = 0; i < 4; i ++) {
		for (int j = 0; j < 4; j ++) {
			int m = 0;
			int n = 0;
			for (int k = 0; k < 4; k ++) {
				if (k == i) {
					continue;
				}
				for (int l = 0; l < 4; l ++) {
					if (l == j) {
						continue;
					}
					s[m][n] = S[k][l];
					n ++;
				}
				m ++;
				n = 0;
			}
			Sm[i][j] =  s[0][0] * (s[1][1] * s[2][2] - s[1][2] * s[2][1]) +
					s[0][1] * (s[1][2] * s[2][0] - s[1][0] * s[2][2]) +
					s[0][2] * (s[1][0] * s[2][1] - s[1][1] * s[2][0]);
		}
	}
	float det_S = 0.0;
	for (int i = 0; i < 4; i ++) {
		det_S += S[0][i] * Sm[0][i] * powf(-1.0, i);
	}
	float SI[4][4];
	for (int i = 0; i < 4; i ++) {for (int j = 0; j < 4; j ++) {
		SI[i][j] = Sm[j][i] / det_S;
	}}
	// compute sensor fusion gain: K_ij(4x4) = PpHT_ik * MI_kj, sum k
	float K[4][4];
	for (int i = 0; i < 4; i ++) {
		for (int j = 0; j < 4; j ++) {
			K[i][j] = 0.0;
			for (int k = 0; k < 4; k ++) {
				K[i][j] += Pp[i][k] * SI[k][j];
			}
		}
	}
	// compute state: x_i(4) = xp_i + K_ij (z_j - xp_j), sum j
	//					   	 = xp_i + xg_i
	float xg[4];
	for (int i = 0; i < 4; i ++) {
		xg[i] = 0.0;
		for (int j = 0; j < 4; j ++) {
			xg[i] += K[i][j] * (imuFusion->EPKF.z[j] - xp[j]);
		}
		imuFusion->EPKF.x[i] = xp[i] + xg[i];
	}
	// compute co-variance: P_ij(6x6) = Pp_ij + K_ik * Pp_kj, sum k
	float KPp[4][4];
	for (int i = 0; i < 4; i ++)
	{
		for (int j = 0; j < 4; j ++)
		{
			KPp[i][j] = 0.0;
			for (int k = 0; k < 4; k ++)
			{
				KPp[i][j] += K[i][k] * Pp[k][j];
			}
			imuFusion->EPKF.P[i][j] = Pp[i][j] - KPp[i][j];
		}
	}
}
// public functions
// initialize sensor fusion state with first measurement
IMUfusion_result_t IMUFusion_Init(IMUfusion_handler_t *imuFusion, float period) {
	IMUfusion_result_t result = IMUFUSION_OK;
	// initialize control variables
	DELTA_T = period;
	// initialize Euler KF state and co-variance matrices
	for (int i = 0; i < 4; i ++) {
		if (i == 0) {
			imuFusion->EPKF.x[i] = 1.0;
		}
		for (int j = 0; j < 4; j ++) {
			if (j == i) {
				imuFusion->EPKF.P[i][j] = 1.0 + IMU_VARIANCE_G_D;
				imuFusion->EPKF.R[i][j] = 1.0 + IMU_VARIANCE_G_D;
				imuFusion->EPKF.Q[i][j] = 1.0 + IMU_VARIANCE_G_D * DELTA_T * DELTA_T;
			}
		}
	}
	return result;
}
// process sensor fusion state
IMUfusion_result_t IMUFusion_Process(IMUfusion_handler_t *imuFusion, int16_t *imu_data) {
	IMUfusion_result_t result = IMUFUSION_OK;
	// compile sensor fusion input parameters
	imuFusion_get_inputs(imuFusion, imu_data);
	// process Euler parameter Kalman filter
	imuFusion_Process_Euler_KF(imuFusion);
	// compile sensor fusion output parameters
	imuFusion_set_outputs(imuFusion);
	return result;
}
