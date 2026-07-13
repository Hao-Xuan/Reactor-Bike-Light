import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { useDispatch } from 'react-redux';

import { toggleLeftTurn } from '../../store/actions/reactions';

const LeftTurnControl = () => {
    const dispatch = useDispatch();
    const leftTurnToggler = () => {
        dispatch(toggleLeftTurn());
    };
    return (
        <View style={styles.controlContainer}>
            <TouchableOpacity
                style={styles.turnControl}
                onPress={leftTurnToggler}
            />
        </View>
    );
};

const styles = StyleSheet.create({
    controlContainer: {
        height: '100%',
        width: '35%'
    },
    turnControl: {
        width: '100%',
        height: '100%'
    }
});

export default LeftTurnControl;