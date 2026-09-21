"""Apply direct installation or simulated A/B installation."""
from copy import deepcopy
from ecu import write_state


def install(state_path, state, firmware, policy):
    candidate = deepcopy(state)
    active = state['active_slot']
    if policy == 'basic':
        candidate['slots'][active] = firmware
        write_state(state_path, candidate)
        return 'ACCEPTED'
    inactive = 'slot_B' if active == 'slot_A' else 'slot_A'
    candidate['slots'][inactive] = firmware
    if firmware.get('health') != 'GOOD':
        write_state(state_path, candidate)
        print('Health: FAIL; previous active slot retained')
        return 'RECOVERED'
    candidate['active_slot'] = inactive
    write_state(state_path, candidate)
    print('Health: PASS')
    return 'ACCEPTED'
