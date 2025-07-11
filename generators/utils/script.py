add_1_element = [0, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 108, 115, 116, 118, 120, 125, 130]
add_2_elements = [110, 112]
add_3_elements = [111]
remove_1_element = [105, 107, 117, 119, 122, 135, 147, 148, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 172]
remove_2_elements = [109, 136, 165, 173, 186]

class Script:
    def __init__(self, hex: str):
        self.script_info(hex)

    def script_info(self, hex: str):
        bytes = bytearray.fromhex(hex)

        self.opcodes = 0
        self.require_stack_size = 0
        cur_stack_size = 0
        require_alt_stack_size = 0
        alt_stack_size = 0
        self.max_element_size = 0
        i = 0
        while i < len(bytes):
            self.opcodes += 1

            if bytes[i] == 107:
                alt_stack_size += 1
            elif bytes[i] == 108:
                alt_stack_size -= 1

            if bytes[i] < 76 and bytes[i] > 0:
                if self.max_element_size < bytes[i]:
                    self.max_element_size = bytes[i]
                i += bytes[i]
                cur_stack_size += 1
            elif bytes[i] == 76:
                size = bytes[i + 1]
                i += size + 1
                cur_stack_size += 1
                if self.max_element_size < size:
                    self.max_element_size = size
            elif bytes[i] == 77:
                size = bytes[i + 1] + (bytes[i + 2] << 8)
                i += size + 2
                cur_stack_size += 1
                if self.max_element_size < size:
                    self.max_element_size = size
            elif bytes[i] == 78:
                size = bytes[i + 1] + (bytes[i + 2] << 8) + (bytes[i + 3] << 16) + (bytes[i + 4] << 24)
                i += size + 4
                cur_stack_size += 1
                if self.max_element_size < size:
                    self.max_element_size = size
            elif bytes[i] in add_1_element:
                cur_stack_size += 1
            elif bytes[i] in add_2_elements:
                cur_stack_size += 2
            elif bytes[i] in add_3_elements:
                cur_stack_size += 3
            elif bytes[i] in remove_1_element:
                cur_stack_size -= 1
            elif bytes[i] in remove_2_elements:
                cur_stack_size -= 2

            if cur_stack_size > self.require_stack_size:
                self.require_stack_size = cur_stack_size
            if alt_stack_size > require_alt_stack_size:
                require_alt_stack_size = alt_stack_size
            # todo: if we have IF opcodes we can try minimize amount of opcodes

            i += 1

        if require_alt_stack_size > self.require_stack_size:
            self.require_stack_size = require_alt_stack_size

        # due to the specifics of implementation using noir
        self.require_stack_size += 3