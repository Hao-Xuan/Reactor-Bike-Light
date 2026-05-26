import React from 'react';
import { StyleSheet, View, ActivityIndicator, ImageBackground } from 'react-native';
import { useSelector } from 'react-redux';

import ColorSettings from '../controls/ColorSettings';
import PowerSettings from '../controls/PowerSettings';
import ReactorButton from './ReactorButton';
import LeftTurnControl from '../controls/LeftTurnControl';
import RightTurnControl from '../controls/RightTurnControl';
import FlashControl from '../controls/FlashControl';
import PowerControl from '../controls/PowerControl';
import BatteryIndicator from '../indicators/BatteryIndicator';
import Colors from '../../constants/Colors';
import BrakeIndicator from '../indicators/BrakeIndicator';
import CrashIndicator from '../indicators/CrashIndicator';
import TurnIndicator from '../indicators/TurnIndicator';
import ThermIndicator from '../indicators/ThermIndicator';
import VoltIndicator from '../indicators/VoltIndicator';

const ReactorBikeLight = (props) => {
    const [
        powerOn,
        isScanned,
        lightMode,
        colorMode,
        powerMode,
        mainColor
    ] = useSelector(
        state => state.reactors.reactors.filter(
            (reactor) => (reactor.dbId === props.id)
        ).flatMap(
            (reactor) => [
                reactor.powerOn,
                reactor.isScanned,
                reactor.lightMode,
                reactor.colorMode,
                reactor.powerMode,
                reactor.mainColor
            ]
        )
    );
    const unfocusedReactorIds = useSelector(
        state => state.reactors.reactors.filter(
            reactor =>
                (reactor.lightMode === lightMode)
                && (reactor.dbId !== props.id)
        ).map(
            reactor => reactor.dbId
        )
    );
    const displayColor = (lightMode === 'Head')
        ? (colorMode === 0)
            ? `hsl(0, 0%, 100%)`
            : (colorMode === 1)
                ? `hsl(60, 100%, 90%)`        
                : `hsl(180, 100%, 90%)`
        : (lightMode === 'Ground')
            ? `hsl(${360 * mainColor / 765}, 100%, 50%)`
            : (colorMode === 0)
                ? `hsl(0, 100%, 50%)`
                : (colorMode === 1)
                    ?  `hsl(15, 100%, 45%)`
                    : `hsl(345, 100%, 45%)`;
    return (
        <ImageBackground
            source={require('../../assets/reactors/reactor_body.png')}
            style={styles.backgroundImage}
            resizeMode='contain'
        >   
            {!powerOn &&
            <View style={styles.activityContainer}>
                <ActivityIndicator
                    animating={isScanned}
                    color={Colors.bleColor}
                    size='large'
                />   
            </View>}         
            {powerOn &&
            <ImageBackground
                source={require('../../assets/reactors/reactor_lenses.png')}
                style={styles.backgroundImage}
                imageStyle={(powerMode!=="Day") && { tintColor: displayColor }}
                resizeMode='contain'
            >
                <View style={styles.topRowContainer}>
                </View>
                <View style={styles.middleRowContainer}>
                    <LeftTurnControl />
                    <View style={styles.indicatorContainer}>
                        <BrakeIndicator />
                        <TurnIndicator id={props.id} />
                        <CrashIndicator id={props.id} />
                        <FlashControl id={props.id} />
                    </View>
                    <RightTurnControl />
                </View>
                <View style={styles.bottomRowContainer}>
                    <View style={styles.outerColumnContainer}>
                        <View style={styles.reactorsBar}>
                            {(unfocusedReactorIds.length > 0) && <ReactorButton id={unfocusedReactorIds[0]} />}
                            {(unfocusedReactorIds.length > 2) && <ReactorButton id={unfocusedReactorIds[2]} />}
                        </View>
                    </View>
                    <View style={styles.innerColumnContainer}>
                        <BatteryIndicator id={props.id} />                    
                        <View style={styles.infoContainer}>                      
                            <VoltIndicator id={props.id} />  
                            <ThermIndicator id={props.id} />                             
                        </View>   
                        <PowerControl id={props.id} /> 
                    </View>                    
                    <View style={styles.outerColumnContainer}>
                        <View style={styles.reactorsBar}>
                            {(unfocusedReactorIds.length > 1) && <ReactorButton id={unfocusedReactorIds[1]} />}
                            {(unfocusedReactorIds.length > 3) && <ReactorButton id={unfocusedReactorIds[3]} />}
                        </View>
                    </View>
                </View>
                <View style={styles.settingsContainer}>
                    <ColorSettings id={props.id} /> 
                    <PowerSettings id={props.id} />
                </View>
            </ImageBackground>}
        </ImageBackground>
    );
};

const styles = StyleSheet.create({
    backgroundImage: {
        width: '100%',
        height: '100%'
    },
    activityContainer: {
        height: '100%',
        justifyContent: 'center',
        alignItems: 'center'
    },
    indicatorContainer: {
        alignItems: 'center',
        marginBottom: '10%'
    },
    topRowContainer: {
        height: '23%',
        alignItems: "center",
        justifyContent: "flex-end"
    },
    middleRowContainer: {
        marginTop: '10%',
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        width: '100%',
        height: '40%'
    },
    bottomRowContainer: {
        flexDirection: 'row',
        width: '100%',
        height: '22%'
    },
    innerColumnContainer: {
        width: '34%',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: '10%'
    },
    outerColumnContainer: {
        width: '33%'
    },
    settingsContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-around',
        width: '100%'
    },
    reactorsBar: {
        alignItems: 'center',
        height: '100%',
        width: '100%'
    },
    infoContainer: {
        alignItems: 'center'
    }
});

export default ReactorBikeLight;