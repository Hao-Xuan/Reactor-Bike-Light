import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Colors from '../../constants/Colors';

const BrakeIndicator = () => {
    const brakeActive = useSelector(
        state => state.reactions.brakeActive
    );
    return (
        <View style={styles.contentContainer} >
            <MaterialCommunityIcons
                name={brakeActive ? 'alert-octagon' : 'alert-octagon-outline'}
                size={brakeActive ? 50 : 30}
                color={Colors.brakeColor}
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

export default BrakeIndicator;