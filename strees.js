import http from 'k6/http';
import { sleep ,check} from 'k6';

export let options = {
    vus: 1, // 這邊固定負載，分別以1、2個vu 來測試
    duration: '1m', // 持續時間一分鐘
};
export default function () {
    const params = {
        headers: {
            'x-api-key': 'IBcj89MIQ11dBkLALO74u3NGEVbqyXdh6RTxGZt6', 
        },
    };
    // 這邊是要測試的API
    let response = http.get('https://qxvp8ppcac.execute-api.ap-northeast-1.amazonaws.com/dev/custom/IkeX/SomeAPI', params); 

    console.log(response.status);
    console.log(response.body);

    // 驗證結果
    check(response, {
        'is status 200': (r) => r.status === 200,
      });

    // 間隔0.2秒
    sleep(0.2); 
}