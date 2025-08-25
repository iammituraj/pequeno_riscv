# Helper script to check regression results

#!/bin/bash

fail_found=0

while IFS= read -r line; do
    if echo "$line" | grep -q "FAIL"; then
        fail_found=1
        break
    fi
done < ./dump/regress_run_dump/regress_result.txt

if [ "$fail_found" -eq 1 ]; then      
    echo ""                                                                                                                     
    echo "FFFFFFFFFFFFFFFFFFFFFF      AAA               IIIIIIIIII LLLLLLLLLLL             "
    echo "F::::::::::::::::::::F     A:::A              I::::::::I L:::::::::L             "
    echo "F::::::::::::::::::::F    A:::::A             I::::::::I L:::::::::L             "
    echo "FF::::::FFFFFFFFF::::F   A:::::::A            II::::::II LL:::::::LL             "
    echo "  F:::::F       FFFFFF  A:::::::::A             I::::I     L:::::L               "
    echo "  F:::::F              A:::::A:::::A            I::::I     L:::::L               "
    echo "  F::::::FFFFFFFFFF   A:::::A A:::::A           I::::I     L:::::L               "
    echo "  F:::::::::::::::F  A:::::A   A:::::A          I::::I     L:::::L               "
    echo "  F:::::::::::::::F A:::::A     A:::::A         I::::I     L:::::L               "
    echo "  F::::::FFFFFFFFFFA:::::AAAAAAAAA:::::A        I::::I     L:::::L               "
    echo "  F:::::F         A:::::::::::::::::::::A       I::::I     L:::::L               "
    echo "  F:::::F        A:::::AAAAAAAAAAAAA:::::A      I::::I     L:::::L         LLLLLL"
    echo "FF:::::::FF     A:::::A             A:::::A   II::::::II LL:::::::LLLLLLLLL:::::L"
    echo "F::::::::FF    A:::::A               A:::::A  I::::::::I L::::::::::::::::::::::L"
    echo "F::::::::FF   A:::::A                 A:::::A I::::::::I L::::::::::::::::::::::L"
    echo "FFFFFFFFFFF  AAAAAAA                   AAAAAAAIIIIIIIIII LLLLLLLLLLLLLLLLLLLLLLLL"
    echo ""
else
    echo ""                                                                                                                                    
    echo "PPPPPPPPPPPPPPPPP        AAA                 SSSSSSSSSSSSSSS    SSSSSSSSSSSSSSS "
    echo "P::::::::::::::::P      A:::A              SS:::::::::::::::S SS:::::::::::::::S"
    echo "P::::::PPPPPP:::::P    A:::::A            S:::::SSSSSS::::::SS:::::SSSSSS::::::S"
    echo "PP:::::P     P:::::P  A:::::::A           S:::::S     SSSSSSSS:::::S     SSSSSSS"
    echo "  P::::P     P:::::P A:::::::::A          S:::::S            S:::::S            "
    echo "  P::::P     P:::::PA:::::A:::::A         S:::::S            S:::::S            "
    echo "  P::::PPPPPP:::::PA:::::A A:::::A         S::::SSSS          S::::SSSS         "
    echo "  P:::::::::::::PPA:::::A   A:::::A         SS::::::SSSSS      SS::::::SSSSS    "
    echo "  P::::PPPPPPPPP A:::::A     A:::::A          SSS::::::::SS      SSS::::::::SS  "
    echo "  P::::P        A:::::AAAAAAAAA:::::A            SSSSSS::::S        SSSSSS::::S "
    echo "  P::::P       A:::::::::::::::::::::A                S:::::S            S:::::S"
    echo "  P::::P      A:::::AAAAAAAAAAAAA:::::A               S:::::S            S:::::S"
    echo "PP::::::PP   A:::::A             A:::::A  SSSSSSS     S:::::SSSSSSSS     S:::::S"
    echo "P::::::::P  A:::::A               A:::::A S::::::SSSSSS:::::SS::::::SSSSSS:::::S"
    echo "P::::::::P A:::::A                 A:::::AS:::::::::::::::SS S:::::::::::::::SS "
    echo "PPPPPPPPPPAAAAAAA                   AAAAAAASSSSSSSSSSSSSSS    SSSSSSSSSSSSSSS   "
    echo ""
fi