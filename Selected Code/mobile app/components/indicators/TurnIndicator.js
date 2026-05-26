import React, { useState, useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

import Colors from '../../constants/Colors';

const TurnIndicator = (props) => {
    const [leftTurnActive, rightTurnActive] = useSelector(
        state => [state.reactions.leftTurnActive, state.reactions.rightTurnActive]
    );
    const [lightMode, mainColor, strobeRate] = useSelector(
        state => state.reactors.reactors.filter(
            reactor => (reactor.dbId === props.id)
        )
    ).flatMap(
        reactor => [reactor.lightMode, reactor.mainColor, reactor.strobeRate]
    );
    const iconColor = (lightMode === 'Head')
        ? (Colors.headColor)
        : ((lightMode === 'Ground')
            ? (`hsl(${360 * mainColor / 765}, 100%, 50%)`)
            : (Colors.tailColor));
    const [strobeHigh, setStrobeHigh] = useState(false);
    useEffect(() => {
        if (leftTurnActive || rightTurnActive) {
            const strobeTime = 500 - 9000 * strobeRate / 64;
            const timerId = setTimeout(() => {
                setStrobeHigh(!strobeHigh);
            }, strobeTime);
            return () => clearTimeout(timerId);
        } else {
            setStrobeHigh(false);
        }
    }, [leftTurnActive, rightTurnActive, strobeHigh, strobeRate]);
    return (
        <View style={styles.turnRow}>
            <View style={styles.contentContainer} >
                <MaterialCommunityIcons
                    name={(leftTurnActive && strobeHigh) ? 'arrow-left-bold' : 'arrow-left-bold-outline'}
                    size={leftTurnActive ? 50 : 30}
                    color={iconColor}
                />
            </View>
            <View style={styles.contentContainer} >
                <MaterialCommunityIcons
                    name={'exclamation-thick'}
                    size={(leftTurnActive || rightTurnActive) ? 30 : 20}
                    color={iconColor}
                />
            </View>
            <View style={styles.contentContainer} >
                <MaterialCommunityIcons
                    name={(rightTurnActive && strobeHigh) ? 'arrow-right-bold' : 'arrow-right-bold-outline'}
                    size={rightTurnActive ? 50 : 30}
                    color={iconColor}
                />
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    turnRow: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-around',
        width: 100
    },
    contentContainer: {
        alignItems: 'center',
        justifyContent: 'center',
        height: 50,
        width: 50
    }
});

export default TurnIndicator;