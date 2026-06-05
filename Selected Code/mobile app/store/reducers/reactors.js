import {
    ADD_REACTOR,
    REMOVE_REACTOR,
    CHANGE_COLOR_SETTINGS,
    CHANGE_POWER_SETTINGS,
    TURN_POWER_OFF,
    TURN_POWER_ON,
    UPDATE_POWER_CONFIG,
    UPDATE_COLOR_CONFIG,
    CHANGE_FOCUSED_REACTOR,
    UPDATE_HARDWARE_REVISION,
    UPDATE_UPDATE_PROGRESS,
    UPDATE_IS_SCANNED,
    UPDATE_SCAN_STATUS,
    UPDATE_VOICE_STATUS,
    UPDATE_NEW_REACTOR_ID,
    CLEAR_COLOR_UPDATE_ID,
    CLEAR_POWER_UPDATE_ID,
    INSTALL_OTA_UPDATE,
    CLEAR_FIRMWARE_UPDATE_ID
} from '../actions/reactors';

const initialState = {
    reactors: [],
    latestFirmware: "",
    newReactorId: null,
    scanStatus: false,
    voiceStatus: false,
    colorUpdateId: null,
    powerUpdateId: null,
    firmwareUpdateId: null
};

const reactorsReducer = (state = initialState, action) => {
    let updatedReactors = [...state.reactors];
    let reactorIndex;
    let updatedVoiceStatus = state.voiceStatus;
    switch (action.type) {
        case ADD_REACTOR:
            updatedReactors.forEach(
                reactor => {
                    if (reactor.lightMode === action.reactor.lightMode) {
                        reactor.focused = false;
                    }
                });
            updatedReactors.push(action.reactor);
            return {
                ...state,
                reactors: updatedReactors,
                newReactorId: null
            };
        case REMOVE_REACTOR:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.reactorId
            );
            const lightMode = updatedReactors[reactorIndex].lightMode;
            updatedReactors = updatedReactors.filter(
                reactor => reactor.dbId !== action.reactorId
            );
            const newReactorIndex = updatedReactors.findIndex(
                reactor => reactor.lightMode === lightMode
            );
            if (newReactorIndex !== -1) {
                updatedReactors[newReactorIndex].focused = true;
            }
            return {
                ...state,
                reactors: updatedReactors
            };
        case CHANGE_COLOR_SETTINGS:
            reactorIndex = updatedReactors.findIndex(
                reactor => (reactor.dbId === action.dbId)
            );
            if (action.colorSync && (action.lightMode === 'Ground')) {
                updatedReactors.forEach(
                    (reactor) => {
                        if (reactor.colorSync) {
                            reactor.mainColor = action.mainColor;
                            reactor.colorMode = action.colorMode;
                        }
                    });
            }
            if (updatedReactors[reactorIndex].lightMode !== action.lightMode) {
                updatedReactors.forEach(
                    (reactor) => {
                        if (reactor.lightMode === action.lightMode) {
                            reactor.focused = false;
                        }
                    }
                );
                const oldLightMode = updatedReactors[reactorIndex].lightMode;
                const newFocusedIndex = updatedReactors.findIndex(
                    reactor => (
                        (reactor.lightMode === oldLightMode)
                        && (reactor.dbId !== updatedReactors[reactorIndex].dbId)
                    )
                );
                if (newFocusedIndex !== -1) {
                    updatedReactors[newFocusedIndex].focused = true;
                }
            }
            updatedReactors[reactorIndex].mainColor = action.mainColor;
            updatedReactors[reactorIndex].colorMode = action.colorMode;
            updatedReactors[reactorIndex].lightMode = action.lightMode;
            updatedReactors[reactorIndex].colorSync = action.colorSync;
            return {
                ...state,
                reactors: updatedReactors
            };
        case CHANGE_POWER_SETTINGS:
            if (action.powerSync) {
                updatedReactors.forEach(reactor => {
                    if (reactor.powerSync) {
                        reactor.brightness = action.brightness;
                        reactor.powerMode = action.powerMode;
                        reactor.strobeRate = action.strobeRate;
                    }
                });
            }
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.reactorId
            );
            updatedReactors[reactorIndex].powerSync = action.powerSync;
            updatedReactors[reactorIndex].powerMode = action.powerMode;
            updatedReactors[reactorIndex].brightness = action.brightness;
            updatedReactors[reactorIndex].strobeRate = action.strobeRate;
            return {
                ...state,
                reactors: updatedReactors
            };
        case TURN_POWER_OFF:
            reactorIndex = updatedReactors.findIndex(
                reactor => (reactor.dbId === action.dbId)
            );
            if (updatedReactors[reactorIndex].powerSync && (updatedReactors[reactorIndex].batteryLevel !== 0)) {
                updatedReactors.forEach(
                    (reactor) => {
                        if (reactor.powerSync) {
                            reactor.powerOn = false;
                            reactor.isScanned = false;
                            reactor.isLinked = false;
                        }
                    }
                );
            } else {
                const newFocusedIndex = updatedReactors.findIndex(
                    reactor => (
                        reactor.powerOn
                        && (reactor.lightMode === updatedReactors[reactorIndex].lightMode)
                        && (reactor.dbId !== updatedReactors[reactorIndex].dbId)
                        )
                );
                if (newFocusedIndex !== -1) {
                    updatedReactors[newFocusedIndex].focused = true;
                    updatedReactors[reactorIndex].focused = false;   
                }
                updatedReactors[reactorIndex].powerOn = false;
                updatedReactors[reactorIndex].isScanned = false;
                updatedReactors[reactorIndex].isLinked = false;                
            }
            if (updatedReactors.every(reactor => !reactor.powerOn)) {
                updatedVoiceStatus = false;
            }
            return {
                ...state,
                reactors: updatedReactors,
                voiceStatus: updatedVoiceStatus
            }
        case TURN_POWER_ON:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.reactorId
            );
            updatedReactors[reactorIndex].powerOn = action.powerOn;
            updatedReactors[reactorIndex].isScanned = action.isScanned;
            updatedReactors[reactorIndex].isLinked = action.isLinked;
            updatedReactors[reactorIndex].lightMode = action.lightMode;
            updatedReactors[reactorIndex].colorMode = action.colorMode;
            updatedReactors[reactorIndex].mainColor = action.mainColor;
            updatedReactors[reactorIndex].powerMode = action.powerMode;
            updatedReactors[reactorIndex].brightness = action.brightness;
            updatedReactors[reactorIndex].strobeRate = action.strobeRate;
            updatedReactors[reactorIndex].batteryLevel = action.batteryLevel;
            updatedReactors[reactorIndex].therm = action.therm;
            updatedReactors[reactorIndex].firmware = action.firmware;
            updatedReactors[reactorIndex].updateProgress = action.updateProgress;
            console.log("Reactors reducer - power on reactor:",updatedReactors[reactorIndex]);
            return {
                ...state,
                reactors: updatedReactors,
                newReactorId: null,
                scanStatus: true
            };
        case UPDATE_POWER_CONFIG:
            if (state.powerUpdateId) {
                //console.log("Reactors reducer - skipping new power config update:", state.powerUpdateId);
                return {
                    ...state
                };
            }
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.reactorId
            );
            let newPowerUpdateId = null;
            if (updatedReactors[reactorIndex].powerSync) {
                if (
                    (updatedReactors[reactorIndex].powerMode !== action.powerMode)
                    || (updatedReactors[reactorIndex].strobeRate !== action.strobeRate)
                ) {
                    newPowerUpdateId = updatedReactors[reactorIndex].bleId;
                }
                updatedReactors.forEach(reactor => {
                    if (reactor.powerSync && (reactor.dbId !== action.reactorId)) {
                        reactor.powerMode = action.powerMode;
                        reactor.strobeRate = action.strobeRate;
                    }
                });
            }
            updatedReactors[reactorIndex].powerMode = action.powerMode;
            updatedReactors[reactorIndex].brightness = action.brightness;
            updatedReactors[reactorIndex].strobeRate = action.strobeRate;
            updatedReactors[reactorIndex].batteryLevel = action.batteryLevel;
            updatedReactors[reactorIndex].therm = action.therm;
            return {
                ...state,
                reactors: updatedReactors,
                powerUpdateId: newPowerUpdateId
            };
        case UPDATE_COLOR_CONFIG:
            if (state.colorUpdateId) {
                //console.log("Reactors reducer - skipping new color config update:", state.colorUpdateId);
                return {
                    ...state
                };
            }
            reactorIndex = updatedReactors.findIndex(
                reactor => (reactor.dbId === action.dbId)
            );
            if (updatedReactors[reactorIndex].colorSync) {
                updatedReactors.forEach(
                    reactor => {
                        if (reactor.colorSync && (reactor.dbId !== action.dbId)) {
                            reactor.mainColor = action.mainColor;
                            reactor.colorMode = action.colorMode;
                        }
                    });
            }
            updatedReactors[reactorIndex].mainColor = action.mainColor;
            updatedReactors[reactorIndex].colorMode = action.colorMode;
            updatedReactors[reactorIndex].lightMode = action.lightMode;
            const newColorUpdateId = updatedReactors[reactorIndex].colorSync ? updatedReactors[reactorIndex].bleId : null;
            return {
                ...state,
                reactors: updatedReactors,
                colorUpdateId: newColorUpdateId
            };
        case CHANGE_FOCUSED_REACTOR:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.reactorId
            );
            updatedReactors.forEach(reactor => {
                if (reactor.lightMode === updatedReactors[reactorIndex].lightMode) {
                    reactor.focused = false;
                }
            });
            updatedReactors[reactorIndex].focused = true;
            return {
                ...state,
                reactors: updatedReactors
            };
        case UPDATE_HARDWARE_REVISION:
            return {
                ...state,
                latestFirmware: action.revision
            };
        case INSTALL_OTA_UPDATE:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.bleId === action.bleId
            );
            updatedReactors[reactorIndex].updateProgress = 101;
            return {
                ...state,
                reactors: updatedReactors
            }
        case UPDATE_UPDATE_PROGRESS:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.dbId === action.dbId
            );
            updatedReactors[reactorIndex].updateProgress = action.updateProgress;
            return {
                ...state,
                reactors: updatedReactors
            }
        case UPDATE_IS_SCANNED:
            reactorIndex = updatedReactors.findIndex(
                reactor => reactor.bleId === action.bleId
            );
            updatedReactors.forEach(
                reactor => {
                    if (reactor.lightMode === updatedReactors[reactorIndex].lightMode) {
                        reactor.focused = false;
                    }
                });
            updatedReactors[reactorIndex].focused = true;
            updatedReactors[reactorIndex].isScanned = action.isScanned;
            return {
                ...state,
                reactors: updatedReactors,
                scanStatus: false
            }
        case UPDATE_SCAN_STATUS:
            return {
                ...state,
                scanStatus: action.status
            }
        case UPDATE_VOICE_STATUS:
            return {
                ...state,
                voiceStatus: action.status
            }
        case UPDATE_NEW_REACTOR_ID:
            return {
                ...state,
                newReactorId: action.bleId,
                scanStatus: false
            }
        case CLEAR_COLOR_UPDATE_ID:
            return {
                ...state,
                colorUpdateId: null
            }
        case CLEAR_POWER_UPDATE_ID:
            return {
                ...state,
                powerUpdateId: null
            }
        case CLEAR_FIRMWARE_UPDATE_ID:
            return {
                ...state,
                scanStatus: true,
                firmwareUpdateId: null
            }
        default:
            return state;
    }
};

export default reactorsReducer;