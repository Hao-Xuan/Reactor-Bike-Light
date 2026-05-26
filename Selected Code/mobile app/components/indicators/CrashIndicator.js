import React, { useState, useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

import Colors from '../../constants/Colors';

const CrashIndicator = (props) => {
    const strobeRate = useSelector(
        state => state.reactors.reactors.find(
            reactor => (reactor.dbId === props.id)
        ).strobeRate
    );
    const crashActive = useSelector(
        state => state.reactions.crashActive
    );
    const [strobeHigh, setStrobeHigh] = useState(false);
    useEffect(() => {
        if (crashActive) {
            const strobeTime = 500 - 9000 * strobeRate / 64;
            const timerId = setTimeout(() => {
                setStrobeHigh(!strobeHigh);
            }, strobeTime);
            return () => clearTimeout(timerId);
        } else {
            setStrobeHigh(false);
        }
    }, [crashActive, strobeHigh, strobeRate]);
    return (
        <View style={styles.contentContainer} >
            <MaterialCommunityIcons
                name={strobeHigh ? 'alert-octagram' : 'alert-octagram-outline'}
                size={crashActive ? 50 : 30}
                color={Colors.crashColor}
            />
        </View>
    );
};

const styles = StyleSheet.create({
    contentContainer: {
        alignItems: 'center',
        justifyContent: 'center',
        height: 50,
        width: 50
    }
});

export default CrashIndicator;