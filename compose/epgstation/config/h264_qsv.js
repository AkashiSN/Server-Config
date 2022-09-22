const { spawn, execSync } = require('child_process');

const ffmpeg = process.env.FFMPEG;

const input = process.env.INPUT;
const output = process.env.OUTPUT;

const analyzedurationSize = '10M'; // Mirakurun の設定に応じて変更すること
const probesizeSize = '32M'; // Mirakurun の設定に応じて変更すること

const isDualMono = parseInt(process.env.AUDIOCOMPONENTTYPE, 10) == 2;

const args = ['-y'];

// ハードウェアアクセラレーション 設定
Array.prototype.push.apply(args,[
    '-init_hw_device', 'qsv=qsv:hw',
    '-hwaccel', 'qsv',
    '-filter_hw_device', 'qsv',
    '-hwaccel_output_format', 'qsv'
]);

Array.prototype.push.apply(args,[
    '-fflags', '+discardcorrupt',
    '-analyzeduration', analyzedurationSize,
    '-probesize', probesizeSize
]);

// input 設定
Array.prototype.push.apply(args,['-i', input]);

// メタ情報を先頭に置く
Array.prototype.push.apply(args, ['-movflags', 'faststart']);
Array.prototype.push.apply(args, ['-ignore_unknown']);

// video 設定
Array.prototype.push.apply(args, [
    '-vf', 'hwupload=extra_hw_frames=64,vpp_qsv=deinterlace=2,scale_qsv=1920:-1,fps=30000/1001',
    '-c:v', 'h264_qsv',
    '-global_quality', '20',
]);

// dual mono 設定
if (isDualMono) {
    Array.prototype.push.apply(args, [
        '-filter_complex',
        'channelsplit[FL][FR]',
        '-map', '0:v',
        '-map', '[FL]',
        '-map', '[FR]',
        '-metadata:s:a:0', 'language=jpn',
        '-metadata:s:a:1', 'language=eng',
    ]);
    Array.prototype.push.apply(args, [
        '-c:a', 'ac3',
        '-ar', '48000',
        '-ab', '256k'
    ]);
} else {
    // audio dataをコピー
    Array.prototype.push.apply(args, [
        '-c:a', 'aac',
        '-ar', '48000',
        '-ab', '256k'
    ]);
}

// その他設定
Array.prototype.push.apply(args,[
    '-f', 'mp4',
    output
]);

let str = '';
for (let i of args) {
    str += ` ${ i }`
}
console.error(str);


const child = spawn(ffmpeg, args);
child.stderr.on('data', (data) => { console.error(String(data)); });
child.on('error', (err) => {
    console.error(err);
    throw new Error(err);
});

child.on('close', () => {
    execSync('/bin/chown www-data:www-data "' + output + '"');
});

process.on('SIGINT', () => {
    child.kill('SIGINT');
});
