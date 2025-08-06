import argparse

def hex_to_ascii(hex_word, bits=32, strict=False):
    try:
        # Nombre de caractères hex pour le format demandé
        required_len = (bits // 8) * 2

        if strict and len(hex_word) != required_len:
            return ''

        # Si le mot est plus court que prévu mais non vide, on le pad à gauche
        if len(hex_word) < required_len:
            hex_word = hex_word.zfill(required_len)

        # Little endian: split tous les 2 chars et reverse
        bytes_list = [hex_word[i:i+2] for i in range(0, len(hex_word), 2)]
        bytes_list.reverse()

        ascii_chars = []
        for b in bytes_list:
            val = int(b, 16)
            if 32 <= val <= 126:
                ascii_chars.append(chr(val))
            else:
                ascii_chars.append('.')  # non imprimable

        return ''.join(ascii_chars)

    except Exception as e:
        return f"[err:{e}]"

def main():
    parser = argparse.ArgumentParser(description="Convertit des mots little endian (32 ou 64 bits) en ASCII imprimable.")
    parser.add_argument("dump", help="Ex: '0804b160 39617044 6d617045'")
    parser.add_argument("-b", "--bits", type=int, choices=[32, 64], default=32,
                        help="Format du dump (32 ou 64 bits). Par défaut: 32.")
    parser.add_argument("-s", "--strict", action="store_true",
                        help="Active le mode strict : ignore les mots mal alignés/incomplets.")

    args = parser.parse_args()

    words = args.dump.strip().split()

    for w in words:
        ascii_str = hex_to_ascii(w, bits=args.bits, strict=args.strict)
        print(f"{w} -> '{ascii_str}'")

if __name__ == "__main__":
    main()
