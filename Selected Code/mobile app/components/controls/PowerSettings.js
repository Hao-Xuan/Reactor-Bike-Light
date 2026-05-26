import React, { useEffect, useReducer } from 'react';
import {
    StyleSheet,
    View,
    Modal,
    TouchableOpacity,
    Button,
    Text,
    Switch
} from 'react-native';
import { useDispatch, useSelector } from 'react-redux';
import { Ionicons } from '@expo/vector-icons';
import SegmentedControl from '@react-native-segmented-control/segmented-control';
import Slider from '@react-native-community/slider';

import { changePowerSettings } from '../../store/actions/reactors';
import Colors from '../../constants/Colors';

const PowerSettings = (props) => {
    const [
        bleId,
        powerMode,
        powerSync,
        brightness,
        strobeRate
    ] = useSelector(
        (state) => state.reactors.reactors.filter(
            (reactor) => (reactor.dbId === props.id)
        ).flatMap(
            (reactor) => [
                reactor.bleId,
                reactor.powerMode,
                reactor.powerSync,
                reactor.brightness,
                reactor.strobeRate
            ]
        )
    );
    const powerSyncBleIds = useSelector(
        state => state.reactors.reactors.filter(
            reactor => (reactor.powerSync && reactor.powerOn)
        )
    ).map(
        reactor => reactor.bleId
    );
    const [state, localDispatch] = useReducer(
        powerSettingsReducer,
        {
            strobeHigh: (powerMode === 'Day') ? false : true,
            modeIndex: (powerMode === 'Day') ? 0 : ((powerMode === 'Strobe') ? 1 : 2),
            newPowerSync: powerSync,
            newBrightness: brightness,
            newPowerMode: powerMode,
            newStrobeRate: strobeRate,
            modalVisible: false
        }
    );
    function powerSettingsReducer(state, action) {
        switch (action.type) {
            case 'setStrobeHigh': return {
                ...state,
                strobeHigh: action.status
            };
            case 'modalToggler': return {
                ...state,
                newPowerSync: action.sync,
                newBrightness: action.bright,
                newPowerMode: action.mode,
                modeIndex: action.index,
                newStrobeRate: action.rate,
                modalVisible: action.status
            };
            case 'setNewPowerSync': return {
                ...state,
                newPowerSync: action.sync
            };
            case 'toggleModal': return {
                ...state,
                modalVisible: action.status
            };
            case 'setNewPowerMode': return {
                ...state,
                newPowerMode: action.mode,
                modeIndex: action.index
            };
            case 'setNewBrightness': return {
                ...state,
                newBrightness: action.bright
            };
            case 'setNewStrobeRate': return {
                ...state,
                newStrobeRate: action.rate
            };
            default: return {
                ...state
            };
        }
    }
    const globalDispatch = useDispatch();
    const modalToggler = () => {
        localDispatch({
            type: 'modalToggler',
            sync: powerSync,
            bright: brightness,
            mode: powerMode,
            index: (powerMode === 'Day') ? 0 : ((powerMode === 'Strobe') ? 1 : 2),
            rate: strobeRate,
            status: !state.modalVisible
        });
    };
    const switchHandler = (value) => {
        localDispatch({
            type: 'setNewPowerSync',
            sync: value
        });
    };
    const confirmHandler = () => {
        globalDispatch(changePowerSettings(
            props.id,
            state.newPowerSync ? powerSyncBleIds : [bleId],
            state.newPowerSync,
            state.newBrightness,
            state.newPowerMode,
            state.newStrobeRate
        ));
        localDispatch({
            type: 'toggleModal',
            status: !state.modalVisible
        });
    };
    const powerModeSegmentsHandler = (event) => {
        localDispatch({
            type: 'setNewPowerMode',
            mode: event.nativeEvent.value,
            index: event.nativeEvent.selectedSegmentIndex
        });
    };
    const brightnessSliderHandler = (value) => {
        localDispatch({
            type: 'setNewBrightness',
            bright: value
        });
    };
    const strobeRateSliderHandler = (value) => {
        localDispatch({
            type: 'setNewStrobeRate',
            rate: value
        });
    };
    useEffect(() => {
        if (powerMode === 'Strobe') {
            const strobeTime = 500 - 9000 * strobeRate / 64;
            const timerId = setTimeout(() => {
                localDispatch({ type: 'setStrobeHigh', status: !state.strobeHigh});
            }, strobeTime);
            return () => clearTimeout(timerId);
        } else {
            if (powerMode === 'Day') {
                localDispatch({ type: 'setStrobeHigh', status: false, timerId: null });
            } else if (powerMode === 'Full') {
                localDispatch({ type: 'setStrobeHigh', status: true, timerId: null });
            }
        }
    }, [powerMode, strobeRate, state.strobeHigh]);
    return (
        <View>
            <Modal
                animationType='fade'
                transparent={true}
                visible={state.modalVisible}
                onRequestClose={modalToggler}
            >
                <View style={styles.modalContainer}>
                    <View style={styles.controlsContainer}>
                        <View style={styles.titleContainer} >
                            <Text style={styles.text}>Power Settings</Text>
                        </View>
                        <View style={styles.switchBar}>
                            <Text style={styles.text}>Power Sync</Text>
                            <View style={styles.switchContainer}>
                                <Text style={styles.text}>OFF</Text>
                                <Switch
                                    trackColor={{
                                        false: Colors.borderColor,
                                        true: Colors.groundIcon
                                    }}
                                    thumbColor={Colors.buttonText}
                                    onValueChange={switchHandler}
                                    value={state.newPowerSync}
                                />
                                <Text style={styles.text}>ON</Text>
                            </View>
                        </View>
                        <View style={styles.sliderBar}>
                            <Text style={styles.text}>Brightness</Text>
                            <Slider
                                style={styles.slider}
                                minimumValue={0}
                                step={1}
                                maximumValue={3}
                                value={state.newBrightness}
                                minimumTrackTintColor={Colors.borderColor}
                                thumbTintColor={Colors.buttonText}
                                onValueChange={brightnessSliderHandler}
                            />
                        </View>
                        <View style={styles.segmentsBar}>
                            <Text style={styles.text}>Mode</Text>
                            <View style={styles.segmentsContainer}>
                                <SegmentedControl
                                    values={['Day', 'Strobe', 'Full']}
                                    selectedIndex={state.modeIndex}
                                    onChange={powerModeSegmentsHandler}
                                    backgroundColor={Colors.backgroundColor}
                                    tintColor={Colors.borderColor}
                                    fontStyle={{"fontFamily": ""}}
                                />
                            </View>
                        </View>
                        <View style={styles.sliderBar}>
                            <Text style={styles.text}>Strobe Rate</Text>
                            <Slider
                                style={styles.slider}
                                minimumValue={0}
                                step={1}
                                maximumValue={3}
                                value={state.newStrobeRate}
                                minimumTrackTintColor={Colors.borderColor}
                                thumbTintColor={Colors.buttonText}
                                onValueChange={strobeRateSliderHandler}
                            />
                        </View>

                        <View style={styles.buttonsContainer}>
                            <View style={styles.modalButton}>
                                <Button
                                    title="Confirm"
                                    color={Colors.backgroundColor}
                                    onPress={confirmHandler}
                                />
                            </View>
                            <View style={styles.modalButton}>
                                <Button
                                    title="Cancel"
                                    color={Colors.backgroundColor}
                                    onPress={modalToggler}
                                />
                            </View>
                        </View>
                    </View>
                </View>
            </Modal>
            <TouchableOpacity
                onPress={modalToggler}
            >
                <Ionicons
                    name={state.strobeHigh ? 'sunny' : 'sunny-outline'}
                    size={30}
                    color={Colors.buttonText}
                />
            </TouchableOpacity>
        </View>
    );
};

const styles = StyleSheet.create({
    modalContainer: {
        width: '100%',
        height: '93%',
        justifyContent: 'flex-end',
        padding: 20
    },
    titleContainer: {
        alignItems: 'center',
        marginTop: 15
    },
    controlsContainer: {
        width: '100%',
        height: '60%',
        alignItems: 'center',
        justifyContent: 'space-between',
        backgroundColor: Colors.buttonColor,
        borderRadius: 15
    },
    switchBar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        width: '90%'
    },
    switchContainer: {
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center'
    },
    sliderBar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        width: '90%'
    },
    slider: {
        width: '70%',
        marginVertical: 5
    },
    text: {
        color: Colors.backgroundText
    },
    segmentsBar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        width: '90%',
        marginTop: 15
    },
    segmentsContainer: {
        width: '75%'
    },
    buttonsContainer: {
        flexDirection: 'row',
        justifyContent: 'space-around',
        width: '90%',
        marginTop: 10,
        marginBottom: 15
    },
    modalButton: {
        width: '35%',
        padding: 10
    }
});

export default PowerSettings;