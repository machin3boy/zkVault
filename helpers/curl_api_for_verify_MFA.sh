response=$(curl --request POST --url https://kqysqbam9h.execute-api.ap-southeast-2.amazonaws.com/prod/sign --header 'Content-Type: application/json' --data '{"username": "test.zkp", "otp_secret_one": "512416", "otp_secret_two": "261716", "request_id": "222"}')

mfa_provider_data=$(echo "$response" | jq -c '
  [
    [
      "0x28Eb3c396f2466d1aB575f76aA8e9d9CE461B727",
      .signed_message_one.message,
      0,
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    ],
    [
      "0x131BC967A658A7924749217e5Cd046d3B544B606",
      .signed_message_one.message,
      .signed_message_one.v,
      .signed_message_one.r,
      .signed_message_one.s
    ],
    [
      "0x23a0B542C18ce00C7000b70b5fe4B288E11cbC70",
      .signed_message_two.message,
      .signed_message_two.v,
      .signed_message_two.r,
      .signed_message_two.s
    ]
  ]
')

echo "$mfa_provider_data"