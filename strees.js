import http from 'k6/http';
import { sleep ,check} from 'k6';

export let options = {
    vus: 1, // 這邊固定負載，分別以1、2個vu 來測試
    duration: '5s', // 持續時間一分鐘
};
export default function () {
    const params = {
        headers: {
            'x-api-key': 'wNWwFTMS2u34RAYulxR4l1IptsB9kv1K4u87yLKw', 
        },
    };
    // 這邊是要測試的API
    let response = http.get('https://g4bdqz8y3e.execute-api.ap-northeast-1.amazonaws.com/dev/custom/BU01/test', params); 

    console.log(response.status);
    console.log(response.body);

    // 驗證結果
    check(response, {
        'is status 200': (r) => r.status === 200,
      });

    // 間隔1秒
    sleep(0.3); 
}