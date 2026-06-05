import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Colors from '../../constants/Colors';

const VoltIndicator = (props) => {
    const batteryLevel = useSelector(
            state => state.reactors.reactors.find(
                (reactor) => (reactor.dbId === props.id)
            ).batteryLevel
        );
    const batteryPercent = (batteryLevel<3010) 
        ? 1 
        : (batteryLevel<4000) 
            ? (batteryLevel-3000)/10 
            : 100;
    return (
        <View style={styles.contentContainer} >
            <MaterialCommunityIcons
                name={'lightning-bolt'}
                size={20}
                color={`hsl(${120 * batteryPercent / 100}, 100%, 50%)`}
            />
            <Text style={styles.text}>{Number.parseFloat(batteryLevel/1000).toFixed(1)}V</Text>
        </View>
    );
};

const styles = StyleSheet.create({
    contentContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        height: 20,
        width: 100
    },
    text: {
        fontSize: 20,
        color: Colors.backgroundText
    },
        
});

export default VoltIndicator;