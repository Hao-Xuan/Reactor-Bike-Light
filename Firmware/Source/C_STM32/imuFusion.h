/*
 * imuFusion.h
 *
 *  Created on: Oct 13, 2025
 *      Author: drkNRG
 */

#ifndef IMUFUSION_H_
#define IMUFUSION_H_

// sensor fusion control constants
#define	DELTA_T_50HZ (0.02f)
#define	DELTA_T_100HZ (0.01f)
#define	DEG_TO_RAD (M_PI / 180.0f)
#define RAD_TO_DEG (1.0f / DEG_TO_RAD)
#define GEE_TO_MET (9.8f)
#define MET_TO_GEE (1.0f / G_TO_MET)
#define IMU_SCALE_A (8192.0f)
#define	IMU_SCALE_G	(65.5f)
#define IMU_VARIANCE_A_G (0.001f * 0.001f)
#define IMU_VARIANCE_G_D (0.07f * DEG_TO_RAD * 0.07f * DEG_TO_RAD)

typedef enum {
	IMUFUSION_OK,
	IMUFUSION_ERR
} IMUfusion_result_t;
// imu data structure
typedef struct {
	float A[3];
	float W[3];
} IMUfusion_input_t;
// Euler parameter Kalman filter
typedef struct {
	float z[4];
	float A[4][4];
	float R[4][4];
	float Q[4][4];
	float P[4][4];
	float x[4];
} IMUfusion_Euler_KF_t;
// sensor fusion output data
typedef struct {
	float a[3];
	float v[3];
	float w[3];
	float e[3];
} IMUfusion_output_t;
// sensor fusion state and model matrices
typedef struct {
	IMUfusion_input_t IN;
	IMUfusion_Euler_KF_t EPKF;
	IMUfusion_output_t OUT;
} IMUfusion_handler_t;

// public function prototypes
IMUfusion_result_t IMUFusion_Init(IMUfusion_handler_t *imuFusion, float period);
IMUfusion_result_t IMUFusion_Process(IMUfusion_handler_t *imuFusion, int16_t *imu_data);

#endif /* IMUFUSION_H_ */
