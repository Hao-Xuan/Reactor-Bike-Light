export const ADD_REACTOR = 'ADD_REACTOR';
export const REMOVE_REACTOR = 'REMOVE_REACTOR';
export const CHANGE_COLOR_SETTINGS = 'CHANGE_COLOR_SETTINGS';
export const CHANGE_POWER_SETTINGS = 'CHANGE_POWER_SETTINGS';
export const TURN_POWER_OFF = "TURN_POWER_OFF";
export const TURN_POWER_ON = 'TURN_POWER_ON';
export const UPDATE_BATTERY = 'UPDATE_BATTERY';
export const CHANGE_FOCUSED_REACTOR = 'CHANGE_FOCUSED_REACTOR';
export const UPDATE_POWER_CONFIG = 'UPDATE_POWER_CONFIG';
export const UPDATE_COLOR_CONFIG = 'UPDATE_COLOR_CONFIG';
export const UPDATE_REACTIONS = 'UPDATE_REACTIONS';
export const UPDATE_HARDWARE_REVISION = 'UPDATE_HARDWARE_REVISION';
export const UPDATE_UPDATE_PROGRESS = 'UPDATE_UPDATE_PROGRESS';
export const UPDATE_BLE_ID = 'UPDATE_BLE_ID';
export const UPDATE_IS_SCANNED = 'UPDATE_IS_SCANNED';
export const UPDATE_SCAN_STATUS = 'UPDATE_SCAN_STATUS';
export const UPDATE_VOICE_STATUS = 'UPDATE_VOICE_STATUS';
export const UPDATE_NEW_REACTOR_ID = 'UPDATE_NEW_REACTOR_ID';
export const TRANSMIT_REACTIONS = 'TRANSMIT_REACTIONS';
export const CLEAR_COLOR_UPDATE_ID = 'CLEAR_COLOR_UPDATE_ID';
export const CLEAR_POWER_UPDATE_ID = 'CLEAR_POWER_UPDATE_ID';
export const CLEAR_REACTION_UPDATE_ID = 'CLEAR_REACTION_UPDATE_ID';
export const CLEAR_FIRMWARE_UPDATE_ID = 'CLEAR_FIRMWARE_UPDATE_ID';
export const INSTALL_OTA_UPDATE = 'INSTALL_OTA_UPDATE';

import FirmwareRevision from '../../firmware/FirmwareRevision';
import ReactorBLE from '../../models/BleUtilities';
import Reactor from '../../models/Reactor';

import {
    insertReactor,
    deleteReactor,
    fetchReactors,
    updateColorSettings,
    updatePowerSettings,
    updatePowerOff,
    updatePowerOn,
    updatePowerConfig,
    updateColorConfig,
    updateLightMode,
    updateOtaProgress
} from "../../helpers/reactorsDB";


const ble = new ReactorBLE();
const reactorServiceUUID = "0fcb45f5-8b2f-4cab-ade6-67ae2aa261e3";
const colorConfigUUID = "043eecea-04ee-4ac0-b841-8493e963936c";
const powerConfigUUID = "f862efcc-6f8f-4346-957e-1f9a57e87ef3";
const reactionsUUID = "33ca0239-bfbf-43fd-9d7b-cf7f69ff548a";
const otaUpdateUUID = "f7e418f8-2936-4d79-9aba-1db3d2f1a005";
const deviceInformationServiceUUID = "180a";
const hardwareRevisionUUID = "2a27";

export const loadReactors = () => {
    return async (dispatch) => {
        try {
            const dbReactors = await fetchReactors();
            const focused = true;
            const powerOn = false;
            const isScanned = false;
            const isLinked = false;
            const batteryLevel = 0;
            const therm = -273;
            dbReactors.forEach(
                (dbReactor) => {
                    //console.log("Reactors actions - dbReactor:", dbReactor);
                    const newReactor = new Reactor(
                        dbReactor.id,
                        dbReactor.bleId,
                        focused,
                        powerOn,
                        isScanned,
                        isLinked,
                        dbReactor.lightMode,
                        dbReactor.colorSync === "0" ? false : true,
                        +dbReactor.colorMode,
                        +dbReactor.mainColor,
                        dbReactor.powerSync === "0" ? false : true,
                        dbReactor.powerMode,
                        +dbReactor.brightness,
                        +dbReactor.strobeRate,
                        batteryLevel,
                        therm,
                        dbReactor.firmware,
                        +dbReactor.updateProgress
                    );
                    //console.log("Reactors actions - newReactor:", newReactor);
                    dispatch({
                        type: ADD_REACTOR,
                        reactor: newReactor
                    });
                }
            );
        } catch (err) {
            //console.log("Reactors actions - loadReactors error:", err);
        }
    };
};

export const addReactor = (bleId, lightMode) => {
    return async dispatch => {
        try {
            //console.log("Reactors actions - adding reactor:", bleId);
            const dbReactors = await fetchReactors();
            const powerOn = false;
            const colorSync = true;
            const colorSyncIndex = dbReactors.findIndex(
                reactor => reactor.colorSync === "1"
            );
            let colorMode = 0;
            let mainColor = 510;
            if (colorSyncIndex !== -1) {
                colorMode = +dbReactors[colorSyncIndex].colorMode;
                mainColor = +dbReactors[colorSyncIndex].mainColor;
            }
            const powerSync = true;
            const strobeSyncIndex = dbReactors.findIndex(
                reactor => reactor.powerSync === "1"
            );
            let powerMode = "Full";
            let strobeRate = 2;
            let brightness = 3;
            if (strobeSyncIndex !== -1) {
                brightness = +dbReactors[strobeSyncIndex].brightness;
                powerMode = dbReactors[strobeSyncIndex].powerMode;
                strobeRate = +dbReactors[strobeSyncIndex].strobeRate;
            }
            const batteryLevel = 0;
            const therm = -273;
            const firmware = null;
            const updateProgress = 101;
            const dbId = await insertReactor(
                bleId,
                powerOn,
                lightMode,
                colorSync,
                colorMode,
                mainColor,
                powerSync,
                powerMode,
                brightness,
                strobeRate,
                firmware,
                updateProgress
            );
            const focused = true;
            const isScanned = true;
            const isLinked = false;
            const newReactor = new Reactor(
                dbId,
                bleId,
                focused,
                powerOn,
                isScanned,
                isLinked,
                lightMode,
                colorSync,
                colorMode,
                mainColor,
                powerSync,
                powerMode,
                brightness,
                strobeRate,
                batteryLevel,
                therm,
                firmware,
                updateProgress
            );
            dispatch({
                type: ADD_REACTOR,
                reactor: newReactor
            });
        } catch (err) {
            //console.log("Reactors actions - addReactor error:", err);
        }
    };
};

export const removeReactor = (dbId, bleId) => {
    return async (dispatch) => {
        try {
            const isConnected = await ble.connectionCheck(bleId);
            if (isConnected) {
                //console.log("Reactors actions - disconnecting Ble link to Reactor:", bleId);
                ble.disconnectFromReactor(bleId);
            }
            //console.log("Reactors actions - removeReactor:", dbId);
            await deleteReactor(dbId);
            dispatch({
                type: REMOVE_REACTOR,
                reactorId: dbId
            });
        } catch (err) {
            //console.log("Reactors actions - removeReactor error:", err);
        }
    };
};

export const updateVoiceStatus = (state) => {
    //console.log("Reactors actions - updateVoiceStatus:", state);
    return {
        type: UPDATE_VOICE_STATUS,
        status: state
    };
};

export const updateScanStatus = (state) => {
    console.log("Reactors actions - updateScanStatus:", state);
    return {
        type: UPDATE_SCAN_STATUS,
        status: state
    };
};

export const cancelLink = () => {
    console.log("Reactors actions - cancel Reactor link...");
    return {
        type: UPDATE_NEW_REACTOR_ID,
        bleId: null
    };
};

export const stopReactorScan = () => {
    console.log("Reactors actions - stop scanning for Reactors...");
    ble.stopScan();
    return { type: null };
};

export const startReactorScan = () => {
    return async dispatch => {
        try {
            const bleState = await ble.getState();
            if (bleState === "PoweredOff") {
                console.log("Reactors actions - enabling Bluetooth Low-Energy...");
                await ble.enableBle();
            }
            console.log("Reactors actions - start scanning for Reactors...");
            const isScanned = true;
            const bleId = await ble.scanForReactors();
            const dbReactors = await fetchReactors();
            if (dbReactors.some(reactor => reactor.bleId === bleId)) {
                dispatch({
                    type: UPDATE_IS_SCANNED,
                    bleId: bleId,
                    isScanned: isScanned
                })
            } else {
                dispatch({
                    type: UPDATE_NEW_REACTOR_ID,
                    bleId: bleId
                });
            }
        } catch (err) {
            console.log("Reactors actions - scanReactors error:", err);
        }
    }
};

export const linkReactor = (reactor, newReactorFlag) => {
    return async (dispatch) => {
        try {
            console.log("Reactors actions - initiating connection to Reactor:", reactor);
            await ble.connectToReactor(reactor.bleId);
            const powerId = reactor.bleId + ":Power";
            const colorId = reactor.bleId + ":Color";
            const reactionsId = reactor.bleId + ":Reactions";
            const updateId = reactor.bleId + ":Update";
            ble.monitorCharacteristic(
                reactor.bleId,
                powerId,
                reactorServiceUUID,
                powerConfigUUID,
                async (data) => {
                    if (data.length > 1) {
                        const powerModeToken = ble.byteToString([data[0]]);
                        const powerMode = (powerModeToken === "D") ? "Day" : ((powerModeToken === "S") ? "Strobe" : "Full")
                        const brightness = data[1];
                        const strobeRate = data[2]
                        const batteryLevel = 256*data[3]+data[4];
                        const therm = 256*data[5]+data[6];
                        console.log("Reactors actions - read powerConfig:", reactor.bleId, powerMode, brightness, strobeRate, batteryLevel, therm);
                        await updatePowerConfig(reactor.dbId, powerMode, brightness, strobeRate);
                        dispatch(({
                            type: UPDATE_POWER_CONFIG,
                            reactorId: reactor.dbId,
                            powerMode: powerMode,
                            brightness: brightness,
                            strobeRate: strobeRate,
                            batteryLevel: batteryLevel,
                            therm: therm
                        }));
                    }
                }
            );
            ble.monitorCharacteristic(
                reactor.bleId,
                colorId,
                reactorServiceUUID,
                colorConfigUUID,
                async (data) => {
                    if (data.length > 1) {
                        const mainColor = 256 * data[0] + data[1];
                        const colorMode = data[2];
                        const lightModeToken = ble.byteToString([data[3]]);
                        const lightMode = (lightModeToken === "T") ? "Tail" : ((lightModeToken === "H") ? "Head" : "Ground");
                        console.log("Reactors actions - read colorConfig:", reactor.bleId, mainColor, colorMode, lightMode,);
                        await updateColorConfig(reactor.dbId, mainColor, colorMode, lightMode);
                        dispatch(({
                            type: UPDATE_COLOR_CONFIG,
                            dbId: reactor.dbId,
                            mainColor: mainColor,
                            colorMode: colorMode,
                            lightMode: lightMode
                        }))
                    }
                }
            );
            ble.monitorCharacteristic(
                reactor.bleId,
                reactionsId,
                reactorServiceUUID,
                reactionsUUID,
                (data) => {
                    if (data.length > 1) {
                        const brake = data[0] === 1 ? true : false
                        const left = data[1] === 1 ? true : false;
                        const right = data[2] === 1 ? true : false;
                        const x2b = data[3] === 1 ? true : false;
                        const crash = data[4] === 1 ? true : false;
                        console.log("Reactors actions - read reactions:", reactor.bleId, data);
                        dispatch(({
                            type: UPDATE_REACTIONS,
                            brakeActive: brake,
                            leftTurnActive: left,
                            rightTurnActive: right,
                            x2bActive: x2b,
                            crashActive: crash,
                            reactionUpdateId: reactor.bleId
                        }));
                    }
                }
            );
            ble.monitorCharacteristic(
                reactor.bleId,
                updateId,
                reactorServiceUUID,
                otaUpdateUUID,
                async (data) => {
                    if (data.length > 1) {
                        const command = ble.byteToString([data[0]]);
                        if (command === "A") {
                            const startIdx = 4096 * data[1] + 256 * data[2] + 16 * data[3] + data[4];
                            if (startIdx < 32768) {
                                if (startIdx === 0) {
                                    console.log("Reactors actions - starting ota update...");
                                }
                                const addressLow = startIdx % 256;
                                const addressHigh = (startIdx - addressLow) / 256;
                                const addressBytes = [addressHigh, addressLow];
                                const dataBytes = FirmwareRevision.hexArray.slice(startIdx, startIdx + 16);
                                const crc = FirmwareRevision.crcArray[startIdx / 16];
                                const crcLow = crc % 256;
                                const crcHigh = (crc - crcLow) / 256;
                                const crcBytes = [crcHigh, crcLow];
                                const bleData = addressBytes.concat(dataBytes).concat(crcBytes);
                                await ble.writeWithoutResponse(reactor.bleId, reactorServiceUUID, otaUpdateUUID, bleData);
                                console.log("Reactors actions - otaUpdate bleData:", bleData);
                                const checkProgress = startIdx % 256;
                                if (checkProgress === 0) {
                                    const updateProgress = Math.floor(100 * startIdx / 32768);
                                    await updateOtaProgress(reactor.dbId, updateProgress);
                                    dispatch({
                                        type: UPDATE_UPDATE_PROGRESS,
                                        dbId: reactor.dbId,
                                        updateProgress: updateProgress
                                    });
                                }
                            } else if (startIdx === 32768) {
                                console.log("Reactors actions - ota update complete...");
                                await updateOtaProgress(reactor.dbId, 100)
                                dispatch({
                                    type: UPDATE_UPDATE_PROGRESS,
                                    dbId: reactor.dbId,
                                    updateProgress: 100
                                });
                            }
                        }
                    }
                }
            );
            const powerOn = true;
            const isScanned = false;
            const isLinked = true;
            const powerData = await ble.readCharacteristicValue(reactor.bleId, reactorServiceUUID, powerConfigUUID);
            const powerModeToken = ble.byteToString([powerData[0]]);
            const powerMode = (powerModeToken === "D") ? "Day" : ((powerModeToken === "S") ? "Strobe" : "Full")
            const brightness = powerData[1];
            const strobeRate = powerData[2];
            const batteryLevel = 256*powerData[3]+powerData[4];
            const therm = 256*powerData[5]+powerData[6];
            console.log("Reactors actions - initial power config:", reactor.bleId, powerMode, brightness, strobeRate, batteryLevel, therm);
            const colorData = await ble.readCharacteristicValue(reactor.bleId, reactorServiceUUID, colorConfigUUID);
            const mainColor = 256 * colorData[0] + colorData[1];
            const colorMode = colorData[2];
            const lightModeToken = ble.byteToString([colorData[3]]);
            let lightMode = (lightModeToken === "T") ? "Tail" : ((lightModeToken === "H") ? "Head" : "Ground");
            if (newReactorFlag && (lightMode !== reactor.lightMode)) {
                lightMode = reactor.lightMode;
                const colorConfig = ble.compileColorValue(lightMode, colorMode, mainColor);
                await ble.writeWithoutResponse(reactor.bleId, reactorServiceUUID, colorConfigUUID, colorConfig);
            }
            console.log("Reactors actions - initial color config:", reactor.bleId, mainColor, colorMode, lightMode);
            const infoUUID = ble.getFullUUID(deviceInformationServiceUUID);
            const revisionUUID = ble.getFullUUID(hardwareRevisionUUID);
            const firmwareBytes = await ble.readCharacteristicValue(reactor.bleId, infoUUID, revisionUUID);
            console.log("Reactors actions - firmwareBytes: ",firmwareBytes);
            const firmware = ble.byteToString(firmwareBytes);
            console.log("Reactors actions - firmware version: ",firmware);
            const updateData = await ble.readCharacteristicValue(reactor.bleId, reactorServiceUUID, otaUpdateUUID);
            console.log("Reactors actions - updateData: ",updateData);
            const updateVersion = ble.byteToString(updateData);
            console.log("Reactors actions - initial ota update version:", reactor.bleId, updateVersion);
            let updateProgress = reactor.updateProgress;
            if (updateVersion !== firmware) {
                if (updateVersion !== FirmwareRevision.version) {
                    updateProgress = 101;
                    console.log("Reactors actions - old update started, resetting update progress...");
                } else {
                    const resumeCommand = "R";
                    await ble.writeWithoutResponse(reactor.bleId, reactorServiceUUID, otaUpdateUUID, resumeCommand);
                    console.log("Reactors actions - ota update command:", resumeCommand);
                }
            }
            await updatePowerOn(reactor.dbId, powerOn, lightMode, colorMode, mainColor, powerMode, brightness, strobeRate, firmware, updateProgress);
            dispatch({
                type: TURN_POWER_ON,
                reactorId: reactor.dbId,
                powerOn: powerOn,
                isScanned: isScanned,
                isLinked: isLinked,
                lightMode: lightMode,
                colorMode: colorMode,
                mainColor: mainColor,
                powerMode: powerMode,
                brightness: brightness,
                strobeRate: strobeRate,
                batteryLevel: batteryLevel,
                therm: therm,
                firmware: firmware,
                updateProgress: updateProgress
            });
        } catch (err) {
            console.log("Reactors actions - linkReactor error:", err);
        }
    };
};

export const turnPowerOff = (dbId, bleIds) => {
    return async (dispatch) => {
        try {
            bleIds.forEach(
                async (bleId) => {
                    const powerId = bleId + ":Power";
                    const colorId = bleId + ":Color";
                    const reactionsId = bleId + ":Reactions";
                    const updateId = bleId + ":Update";
                    const offCommand = "O";
                    ble.cancelMonitor(powerId, colorId, reactionsId, updateId);
                    await ble.writeWithoutResponse(bleId, reactorServiceUUID, powerConfigUUID, offCommand);
                    //console.log("Reactors actions - power off Reactor:", bleId);
                }
            );
            await updatePowerOff(dbId);
            dispatch({
                type: TURN_POWER_OFF,
                dbId: dbId
            })
        } catch (err) {
            //console.log("Reactors actions - togglePowerOff error:", err);
        }
    }
};

export const changeColorSettings = (dbId, bleIds, colorSync, mainColor, colorMode, lightMode) => {
    return async (dispatch) => {
        try {
            const value = ble.compileColorValue(lightMode, colorMode, mainColor);
            bleIds.forEach(
                async (bleId) => {
                    await ble.writeWithoutResponse(bleId, reactorServiceUUID, colorConfigUUID, value);
                    //console.log("Reactors actions - write color config:", value, "to Reactor:", bleId);
                }
            );
            await updateColorSettings(dbId, colorSync, mainColor, colorMode);
            await updateLightMode(dbId, lightMode);
            dispatch({
                type: CHANGE_COLOR_SETTINGS,
                dbId: dbId,
                colorSync: colorSync,
                mainColor: mainColor,
                colorMode: colorMode,
                lightMode: lightMode
            });
        } catch (err) {
            //console.log("Reactors actions - changeColorSettings error:", err);
        }
    };
};

export const changePowerSettings = (dbId, bleIds, powerSync, brightness, powerMode, strobeRate) => {
    return async (dispatch) => {
        try {
            const value = ble.compilePowerValue(powerMode, brightness, strobeRate);
            bleIds.forEach(
                async (bleId) => {
                    await ble.writeWithoutResponse(bleId, reactorServiceUUID, powerConfigUUID, value);
                    //console.log("Reactors actions - write power config:", value, "to Reactor:", bleId);
                }
            )
            await updatePowerSettings(dbId, powerSync, brightness, powerMode, strobeRate);
            dispatch({
                type: CHANGE_POWER_SETTINGS,
                reactorId: dbId,
                powerSync: powerSync,
                brightness: brightness,
                powerMode: powerMode,
                strobeRate: strobeRate
            });
        } catch (err) {
            //console.log("Reactors actions - changePowerSettings error:", err);
        }
    };
};

export const updateColor = (bleIds, lightMode, colorMode, mainColor) => {
    return async dispatch => {
        try {
            if (bleIds.length > 0) {
                const value = ble.compileColorValue(lightMode, colorMode, mainColor);
                bleIds.forEach(
                    async (bleId) => {
                        //console.log("Reactors actions - updateColor:", value, "to Reactor:", bleId);
                        await ble.writeWithoutResponse(bleId, reactorServiceUUID, colorConfigUUID, value);
                    }
                );
            }
            dispatch({
                type: CLEAR_COLOR_UPDATE_ID
            });
        } catch (err) {
            //console.log("Reactors actions - update color error:", err);
        }
    }
};

export const updatePower = (reactorData, powerMode, strobeRate) => {
    return async dispatch => {
        try {
            if (reactorData.length > 0) {
                reactorData.forEach(
                    async (data) => {
                        const bleId = data[0];
                        const brightness = data[1];
                        const value = ble.compilePowerValue(powerMode, brightness, strobeRate);
                        await ble.writeWithoutResponse(bleId, reactorServiceUUID, powerConfigUUID, value);
                        //console.log("Reactors actions - update power:", value, "to Reactor:", bleId);
                    }
                );
            }
            dispatch({
                type: CLEAR_POWER_UPDATE_ID
            });
        } catch (err) {
            //console.log("Reactors actions - updatePower error:", err);
        }
    }
};

export const updateReactions = (bleIds, brake, left, right, x2b, crash) => {
    return async dispatch => {
        try {
            if (bleIds.length > 0) {
                const brakeActive = brake ? "1" : "0"
                const leftTurnActive = left ? "1" : "0";
                const rightTurnActive = right ? "1" : "0";
                const x2bActive = x2b ? "1" : "0";
                const crashActive = crash ? "1" : "0";
                const value = brakeActive + leftTurnActive + rightTurnActive + x2bActive + crashActive;
                bleIds.forEach(
                    async (bleId) => {
                        await ble.writeWithoutResponse(bleId, reactorServiceUUID, reactionsUUID, value);
                        //console.log("Reactors actions - update reactions:", bleId, value);
                    }
                );
            }
            dispatch({
                type: CLEAR_REACTION_UPDATE_ID
            });
        } catch (err) {
            //console.log("Reactors actions - bleReactions error:", err);
        }
    }
};

export const changeFocusedReactor = (dbId) => {
    return {
        type: CHANGE_FOCUSED_REACTOR,
        reactorId: dbId
    };
};

export const loadFirmware = () => {
    return {
        type: UPDATE_HARDWARE_REVISION,
        revision: FirmwareRevision.version
    };
};

export const startOtaUpdate = (bleId) => {
    return async () => {
        try {
            const startCommand = "S" + FirmwareRevision.version;
            await ble.writeWithoutResponse(bleId, reactorServiceUUID, otaUpdateUUID, startCommand);
            console.log("Reactors actions - ota update command:", startCommand);
        } catch (err) {
            console.log("Reactors actions - startOtaUpdate error:", err);
        }
    };
};

export const startOtaInstall = (bleId) => {
    return async (dispatch) => {
        try {
            const installCommand = "I";
            await ble.writeWithoutResponse(bleId, reactorServiceUUID, otaUpdateUUID, installCommand);
            dispatch({
                type: INSTALL_OTA_UPDATE,
                bleId: bleId
            });
        } catch (err) {
            console.log("Reactors actions - startOtaUpdate error:", err);
        }
    };
};

export const clearFirmwareUpdateId = () => {
    return {
        type: CLEAR_FIRMWARE_UPDATE_ID
    };
};