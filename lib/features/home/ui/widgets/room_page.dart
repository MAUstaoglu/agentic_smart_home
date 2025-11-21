import 'package:flutter/material.dart';
import 'package:flutter_ui_agent/flutter_ui_agent.dart';
import 'package:provider/provider.dart';

import '../../models/room_model.dart';
import '../../providers/app_state.dart';

class RoomPage extends StatelessWidget {
  final Room room;
  const RoomPage({super.key, required this.room});

  String _colorToString(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.green) return 'green';
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              _buildLightControl(context, appState),
              const SizedBox(height: 20),
              _buildColorControl(context, appState),
              const SizedBox(height: 20),
              _buildThermostatControl(context, appState),
              if (room.roomName == RoomName.livingRoom) ...[
                const SizedBox(height: 20),
                _buildTVControl(context, appState),
              ],
              if (room.roomName == RoomName.garage) ...[
                const SizedBox(height: 20),
                _buildGarageGateControl(context, appState),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLightControl(BuildContext context, AppState appState) {
    return AiActionWidget(
      actionId: 'toggle_light_${room.name.replaceAll(' ', '_').toLowerCase()}',
      description: 'Set the light in the ${room.name} on or off',
      parameters: const [AgentActionParameter.boolean(name: 'on')],
      onExecuteWithParams: (params) {
        final on = params['on'] as bool?;
        if (on != null) {
          room.lightOn = on;
          appState.updateRoom(room);
        }
      },
      child: SwitchListTile(
        title: const Text('Room Light'),
        value: room.lightOn,
        onChanged: (value) {
          room.lightOn = value;
          appState.updateRoom(room);
        },
        secondary: Icon(
          room.lightOn ? Icons.lightbulb : Icons.lightbulb_outline,
        ),
      ),
    );
  }

  Widget _buildColorControl(BuildContext context, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ambient Light Color'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            for (final color in [Colors.red, Colors.blue, Colors.green])
              AiActionWidget(
                actionId:
                    'set_color_${_colorToString(color).toLowerCase()}_${room.name.replaceAll(' ', '_').toLowerCase()}',
                description:
                    'Set ambient light color to ${_colorToString(color).toLowerCase()} in ${room.name}',
                onExecute: () {
                  room.ambientColor = color;
                  appState.updateRoom(room);
                },
                child: ChoiceChip(
                  label: Text(_colorToString(color).toUpperCase()),
                  selected: room.ambientColor == color,
                  onSelected: (selected) {
                    if (selected) {
                      room.ambientColor = color;
                      appState.updateRoom(room);
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildThermostatControl(BuildContext context, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thermostat: ${room.temperature.toStringAsFixed(1)}°C'),
        AiActionWidget(
          actionId:
              'set_temperature_${room.name.replaceAll(' ', '_').toLowerCase()}',
          description: 'Set thermostat temperature in the ${room.name}',
          parameters: const [AgentActionParameter.number(name: 'temperature')],
          onExecuteWithParams: (params) {
            final temp = params['temperature'] as double?;
            if (temp != null) {
              room.temperature = temp.clamp(18.0, 30.0);
              appState.updateRoom(room);
            }
          },
          child: Slider(
            value: room.temperature,
            min: 18,
            max: 30,
            divisions: 12,
            label: '${room.temperature.round()}°C',
            onChanged: (value) {
              room.temperature = value;
              appState.updateRoom(room);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTVControl(BuildContext context, AppState appState) {
    return AiActionWidget(
      actionId: 'toggle_tv_${room.name.replaceAll(' ', '_').toLowerCase()}',
      description: 'Turn the TV in the ${room.name} on or off',
      parameters: const [AgentActionParameter.boolean(name: 'on')],
      onExecuteWithParams: (params) {
        final on = params['on'] as bool?;
        if (on != null) {
          room.tvOn = on;
          appState.updateRoom(room);
        }
      },
      child: SwitchListTile(
        title: const Text('Television'),
        value: room.tvOn,
        onChanged: (value) {
          room.tvOn = value;
          appState.updateRoom(room);
        },
        secondary: Icon(room.tvOn ? Icons.tv : Icons.tv_off),
      ),
    );
  }

  Widget _buildGarageGateControl(BuildContext context, AppState appState) {
    return AiActionWidget(
      actionId: 'toggle_gate_${room.name.replaceAll(' ', '_').toLowerCase()}',
      description: 'Open or close the gate in the ${room.name}',
      parameters: const [AgentActionParameter.boolean(name: 'open')],
      onExecuteWithParams: (params) {
        final open = params['open'] as bool?;
        if (open != null) {
          room.garageGateOpen = open;
          appState.updateRoom(room);
        }
      },
      child: SwitchListTile(
        title: const Text('Garage Gate'),
        value: room.garageGateOpen,
        onChanged: (value) {
          room.garageGateOpen = value;
          appState.updateRoom(room);
        },
        secondary: Icon(
          room.garageGateOpen ? Icons.garage_outlined : Icons.garage,
        ),
      ),
    );
  }
}
