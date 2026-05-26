import React from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { ProgressBar } from '@react-native-community/progress-bar-android';
import { useSelector } from 'react-redux';

import Colors from '../../constants/Colors';

const UpdateProgressBar = (props) => {
    const updateProgress = useSelector(
        state => state.reactors.reactors.find(
            reactor => reactor.dbId === props.id
        ).updateProgress
    );
    return (
        <View style={styles.progressContainer}>
            <Text style={styles.text}>{updateProgress}%</Text>
            <View style={styles.barContainer}>
                <View style={styles.bar}>
                    <ProgressBar
                        styleAttr="Horizontal"
                        color={Colors.bleColor}
                        indeterminate={false}
                        progress={updateProgress / 100}
                    />
                </View>
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    progressContainer: {
        alignItems: 'center'
    },
    barContainer: {
        flexDirection: 'row'
    },
    bar: {
        flex: 0.25
    },
    text: {
        color: Colors.borderColor
    }
});

export default UpdateProgressBar;