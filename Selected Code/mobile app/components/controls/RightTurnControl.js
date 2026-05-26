import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { useDispatch } from 'react-redux';

import { toggleRightTurn } from '../../store/actions/reactions';

const RightTurnControl = () => {
    const dispatch = useDispatch();
    const rightTurnToggler = () => {
        dispatch(toggleRightTurn());
    };
    return (
        <View style={styles.controlContainer}>
            <TouchableOpacity
                style={styles.turnControl}
                onPress={rightTurnToggler}
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

export default RightTurnControl;