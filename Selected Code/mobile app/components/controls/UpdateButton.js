import React, { useState, useEffect } from 'react';
import { useNavigation } from '@react-navigation/native';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useSelector } from 'react-redux';

import Colors from '../../constants/Colors';

const UpdateButton = (props) => {
    const [currentFirmware, updateProgress] = useSelector(
        state => state.reactors.reactors.filter(
            reactor => reactor.dbId === props.id
        ).flatMap(
            reactor => [
                reactor.firmware,
                reactor.updateProgress
            ]
        )
    );
    const latestFirmware = useSelector(
        state => state.reactors.latestFirmware
    );
    const updateAvailable = (currentFirmware !== latestFirmware);
    const navigation = useNavigation();
    const goToUpdates = () => {
        navigation.navigate("Update", { id: props.id });
    };
    return (
        updateAvailable && <TouchableOpacity
            onPress={goToUpdates}
        >
            <View style={styles.updateContainer}>
                <Text style={styles.text}>Update</Text>
                {(updateProgress === 101) &&
                    <Text style={styles.text}>Available</Text>
                }
                {(updateProgress === 100) &&
                    <Text style={styles.text}>Ready to Install</Text>
                }
                {(updateProgress < 100) &&
                    <Text style={styles.text}>Downloading: {updateProgress}%</Text>
                }
            </View>
        </TouchableOpacity>
    )
};

const styles = StyleSheet.create({
    updateContainer: {
        justifyContent: 'center',
        alignItems: 'center',
        height: '100%',
        width: '100%'
    },
    text: {
        color: Colors.buttonText
    }
});

export default UpdateButton;