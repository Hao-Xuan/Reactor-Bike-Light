import React, { useReducer } from 'react';
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
import { useNavigation } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import SegmentedControl from '@react-native-segmented-control/segmented-control';
import Slider from '@react-native-community/slider';
import { LinearGradient } from 'expo-linear-gradient';

import { changeColorSettings } from '../../store/actions/reactors';
import Colors from '../../constants/Colors';

const ColorSettings = (props) => {
    const [
        bleId,
        lightMode,
        colorMode,
        mainColor,
        colorSync
    ] = useSelector(
        state => state.reactors.reactors.filter(
            (reactor) => (reactor.dbId === props.id)
        ).flatMap(
            (reactor) => [
                reactor.bleId,
                reactor.lightMode,
                reactor.colorMode,
                reactor.mainColor,
                reactor.colorSync
            ]
        )
    );
    let colorSyncBleIds = useSelector(
        state => state.reactors.reactors.filter(
            reactor => (reactor.colorSync && reactor.powerOn && (reactor.lightMode === 'Ground'))
        ).map(
            reactor => reactor.bleId
        )
    );
    const [state, localDispatch] = useReducer(
        colorSettingsReducer,
        {
            newLightMode: lightMode,
            lightModeIndex: (lightMode === 'Tail') ? 2 : ((lightMode === 'Ground') ? 1 : 0),
            newColorMode: colorMode,
            newMainColor: mainColor,
            colorIndex: mainColor,
            pointerColor: `hsl(${360 * mainColor / 765}, 100%, 50%)`,
            newColorSync: colorSync,
            modalVisible: false
        }
    );
    function colorSettingsReducer(state, action) {
        //console.log("ColorSettings - state.newColorMode:", state.newColorMode);
        switch (action.type) {
            case 'sliderHandler': return {
                ...state,
                colorIndex: action.index,
                newMainColor: action.color,
                pointerColor: action.pointer
            };
            case 'setNewColorSync': return {
                ...state,
                newColorSync: action.status
            };
            case 'toggleModal': return {
                ...state,
                modalVisible: action.status
            };
            case 'setNewColorMode': return {
                ...state,
                newColorMode: action.mode
            };
            case 'setNewLightMode': return {
                ...state,
                newLightMode: action.mode,
                lightModeIndex: action.index
            };
            case 'modalToggler': return {
                ...state,
                modalVisible: action.status,
                newLightMode: action.lightMode,
                lightModeIndex: action.lightModeIndex,
                newColorMode: action.colorMode,
                newMainColor: action.color,
                colorIndex: action.colorIndex,
                newColorSync: action.sync,
                pointerColor: action.pointer
            };
            default: return {
                ...state
            };
        }
    }
    const navigation = useNavigation();
    const globalDispatch = useDispatch();
    const sliderHandler = (value) => {
        localDispatch({
            type: 'sliderHandler',
            index: value,
            color: value,
            pointer: `hsl(${360 * value / 765}, 100%, 50%)`
        });
    };
    const switchHandler = () => {
        localDispatch({
            type: 'setNewColorSync',
            status: !state.newColorSync
        });
    };
    const modalToggler = () => {
        //console.log("ColorSettings - colorMode:", colorMode);
        localDispatch({
            type: 'modalToggler',
            status: !state.modalVisible,
            lightMode: lightMode,
            lightModeIndex: (lightMode === 'Tail') ? 2 : ((lightMode === 'Ground') ? 1 : 0),
            colorMode: colorMode,
            color: mainColor,
            colorIndex: mainColor,
            sync: colorSync,
            pointer: `hsl(${360 * mainColor / 765}, 100%, 50%)`
        });
    };
    const confirmHandler = () => {
        if (state.newColorSync && (state.newLightMode === "Ground") && (state.newLightMode !== lightMode)) {
            colorSyncBleIds.push(bleId);
        }
        globalDispatch(changeColorSettings(
            props.id,
            (state.newColorSync && (state.newLightMode === "Ground")) ? colorSyncBleIds : [bleId],
            state.newColorSync,
            state.newMainColor,
            state.newColorMode,
            state.newLightMode
        ));
        localDispatch({
            type: 'toggleModal',
            status: !state.modalVisible
        });
        if (state.newLightMode !== lightMode) {
            navigation.navigate(state.newLightMode);
        }
    };
    const colorModeSegmentsHandler = (event) => {
        //console.log("ColorSettings - newColorMode:", event);
        localDispatch({
            type: 'setNewColorMode',
            mode: event.nativeEvent.selectedSegmentIndex
        });
    };
    const lightModeSegmentsHandler = (event) => {
        //console.log("ColorSettings - newLightMode:", event);
        localDispatch({
            type: 'setNewLightMode',
            mode: event.nativeEvent.value,
            index: event.nativeEvent.selectedSegmentIndex
        });
    };
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
                            <Text style={styles.text}>Color Settings</Text>
                        </View>
                        {(lightMode === "Ground") &&
                        <View style={styles.switchBar}>
                            <Text style={styles.text}>Color Sync</Text>
                            <View style={styles.switchContainer}>
                                <Text style={styles.text}>OFF</Text>
                                <Switch
                                    trackColor={{
                                        false: Colors.borderColor,
                                        true: Colors.groundIcon
                                    }}
                                    thumbColor={Colors.buttonText}
                                    onValueChange={switchHandler}
                                    value={state.newColorSync}
                                />
                                <Text style={styles.text}>ON</Text>
                            </View>
                        </View>
                        }
                        {(lightMode === "Ground") &&
                        <View style={styles.colorContainer}>
                            <View style={styles.colorBarContainer}>
                                <View style={{
                                    ...styles.colorIndicator,
                                    marginLeft: `${2 + state.colorIndex * 179 / 765}%`
                                }}>
                                    <Ionicons
                                        name='triangle-sharp'
                                        size={25}
                                        color={state.pointerColor}
                                        style={{ transform: [{ rotateZ: '180deg' }] }}
                                    />
                                </View>
                                <View style={styles.gradientBar}>
                                    <LinearGradient
                                        colors={[
                                            'hsl(0, 100%, 50%)',
                                            'hsl(30, 100%, 50%)',
                                            'hsl(60, 100%, 50%)',
                                            'hsl(90, 100%, 50%)',
                                            'hsl(120, 100%, 50%)',
                                            'hsl(180, 100%, 50%)',
                                            'hsl(210, 100%, 50%)',
                                            'hsl(240, 100%, 50%)',
                                            'hsl(270, 100%, 50%)',
                                            'hsl(300, 100%, 50%)',
                                            'hsl(330, 100%, 50%)',
                                            'hsl(360, 100%, 50%)'
                                        ]}
                                        style={styles.gradient}
                                        start={{ x: 0, y: 0.5 }}
                                        end={{ x: 1, y: 0.5 }}
                                    />
                                </View>
                                <Slider
                                    style={styles.slider}
                                    minimumValue={0}
                                    step={1}
                                    maximumValue={764}
                                    value={state.colorIndex}
                                    minimumTrackTintColor={Colors.backgroundColor}
                                    maximumTrackTintColor={Colors.backgroundColor}
                                    thumbTintColor={Colors.buttonText}
                                    onValueChange={sliderHandler}
                                />
                            </View>
                        </View>
                        }
                        {(lightMode === "Head") &&
                        <View style={styles.segmentBar}>
                            <Text style={styles.text}>Shade</Text>
                            <View style={styles.segmentsContainer}>
                                <SegmentedControl
                                    values={['Bright', 'Warm', 'Cool']}
                                    selectedIndex={state.newColorMode}
                                    onChange={colorModeSegmentsHandler}
                                    backgroundColor={Colors.backgroundColor}
                                    tintColor={Colors.borderColor}
                                    fontStyle={{"fontFamily": ""}}
                                />
                            </View>
                        </View>
                        }
                        {(lightMode === "Ground") &&
                        <View style={styles.segmentBar}>
                            <Text style={styles.text}>Control</Text>
                            <View style={styles.segmentsContainer}>
                                <SegmentedControl
                                    values={['Motion', 'Pattern', 'Static']}
                                    selectedIndex={state.newColorMode}
                                    onChange={colorModeSegmentsHandler}
                                    backgroundColor={Colors.backgroundColor}
                                    tintColor={Colors.borderColor}
                                    fontStyle={{"fontFamily": ""}}
                                />
                            </View>
                        </View>
                        }
                        {(lightMode === "Tail") &&
                        <View style={styles.segmentBar}>
                            <Text style={styles.text}>Shade</Text>
                            <View style={styles.segmentsContainer}>
                                <SegmentedControl
                                    values={['Bright', 'Warm', 'Hot']}
                                    selectedIndex={state.newColorMode}
                                    onChange={colorModeSegmentsHandler}
                                    backgroundColor={Colors.backgroundColor}
                                    tintColor={Colors.borderColor}
                                    fontStyle={{"fontFamily": ""}}
                                />
                            </View>
                        </View>
                        }
                        <View style={styles.segmentBar}>
                            <Text style={styles.text}>Mode</Text>
                            <View style={styles.segmentsContainer}>
                                <SegmentedControl
                                    values={['Head', 'Ground', 'Tail']}
                                    selectedIndex={state.lightModeIndex}
                                    onChange={lightModeSegmentsHandler}
                                    backgroundColor={Colors.backgroundColor}
                                    tintColor={Colors.borderColor}
                                    fontStyle={{"fontFamily": ""}}
                                />
                            </View>
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
                    name='color-palette-outline'
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
        borderRadius: 15,
        padding: 5
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
    text: {
        color: Colors.backgroundText
    },
    colorContainer: {
        flexDirection: 'row',
        height: '17%',
        width: '100%',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 20,
        marginTop: 20
    },
    colorBarContainer: {
        width: '100%',
        justifyContent: 'space-between',
        alignItems: 'center'
    },
    colorIndicator: {
        justifyContent: 'flex-end',
        alignItems: 'flex-start',
        width: '100%'
    },
    gradientBar: {
        width: '90%',
        height: '100%'
    },
    gradient: {
        position: 'relative',
        left: 0,
        right: 0,
        top: 0,
        height: '100%',
        justifyContent: 'flex-start'
    },
    slider: {
        width: '100%',
        marginTop: 5
    },
    segmentBar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        width: '90%',
        marginTop: 15
    },
    segmentsContainer: {
        width: '80%'
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

export default ColorSettings;