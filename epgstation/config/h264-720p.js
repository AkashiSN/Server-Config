const spawn = require('child_process').spawn;
const ffmpeg = process.env.FFMPEG;

const input = process.env.INPUT;
const output = process.env.OUTPUT;

const analyzedurationSize = '10M'; // Mirakurun の設定に応じて変更すること
const probesizeSize = '32M'; // Mirakurun の設定に応じて変更すること

const dualMonoMode = 'main';
const isDualMono = parseInt(process.env.AUDIOCOMPONENTTYPE, 10) == 2;

const args = [
    '-fflags', '+discardcorrupt',
    '-y',
    '-analyzeduration', analyzedurationSize,
    '-probesize', probesizeSize
];

// dual mono 設定
if (isDualMono) {
    Array.prototype.push.apply(args, ['-dual_mono_mode', dualMonoMode]);
}

// ハードウェアアクセラレーション 設定
Array.prototype.push.apply(args,[
    '-deint', 'adaptive',
    '-drop_second_field', '1',
    '-hwaccel', 'cuvid',
    '-hwaccel_output_format', 'cuda'
]);

// input 設定
Array.prototype.push.apply(args,['-i', input]);

// メタ情報を先頭に置く
Array.prototype.push.apply(args,['-movflags', 'faststart']);

// video filter 設定
Array.prototype.push.apply(args, [
    '-vf', 'yadif_cuda,scale_npp=-1:720:interp_algo=lanczos'
]);

// その他設定
Array.prototype.push.apply(args,[
    '-aspect', '16:9',
    '-c:v', 'libx264',
    '-crf', '23',
    '-f', 'mp4',
    '-c:a', 'aac',
    '-ar', '48000',
    '-ab', '256k',
    '-ac', '2',
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

process.on('SIGINT', () => {
    child.kill('SIGINT');
});

