"""Unattended, silent four-client soak. Only isolated lab profiles are used.

No player installation changes and no automatic stable release/publication.
"""
import argparse
import hashlib
import json
import os
import socket
import subprocess
import sys
import time
import traceback
import msvcrt
from pathlib import Path

import psutil
import session_support as s


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--minutes',type=float,default=90)
    parser.add_argument('--smoke',action='store_true',help='Short validation, not long-session evidence')
    args=parser.parse_args()
    if not 0.25 <= args.minutes <= 720:parser.error('minutes must be between 0.25 and 720')
    (s.ROOT/'local').mkdir(exist_ok=True)
    lock=(s.ROOT/'local/long-test.lock').open('a+b')
    lock.write(b'0')
    lock.flush()
    lock.seek(0)
    try:msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
    except OSError:
        print('Another long test is already running. Do not start a second copy.',flush=True)
        return 2
    out=s.ROOT/'local'/f'long-test-{s.run_id}'
    out.mkdir(parents=True)
    os.environ.update(NEEDLENET_COMPACT='1',NEEDLENET_LOG_DIR=str(out),NN_RENDER_HOST='1')
    os.environ.pop('NEEDLENET_RESTORE',None)
    report={'run_id':s.run_id,'status':'RUNNING','smoke':args.smoke,'requested_minutes':args.minutes,'output':str(out),'checks':[],
            'coverage_gaps':['All end-to-end production chains and purchase/unlock progression are not certified by isolated machine probes.',
                             'Separate-PC Steam transport is outside this local ENet test.'],
            'audio_driver':'Dummy','machine_probes':{},'save_load_cycles':0,'samples':0,'peak_rss_mib':{}}
    (s.ROOT/'local/long-test-current.json').write_text(json.dumps({'pid':os.getpid(),'output':str(out)},indent=2),encoding='utf-8')
    (s.ROOT/'local/LONG-TEST-RESULT.txt').write_text('RUNNING - do not send an older result.\nCurrent output: '+str(out)+'\n',encoding='utf-8')
    relay=None
    metadata={}
    started=time.monotonic()
    stage='preflight'
    strands=0
    belts=0
    soak_start=None
    metrics=(out/'metrics.jsonl').open('a',encoding='utf-8',buffering=1)

    def persist():
        report['stage']=stage
        temporary=out/'result.tmp'
        temporary.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        temporary.replace(out/'result.json')

    def note(name,**detail):
        report['checks'].append({'name':name,'wall_time':time.time(),**detail})
        print(time.strftime('%H:%M:%S'),name,json.dumps(detail,ensure_ascii=True),flush=True)
        persist()

    def host(ss):return next(a for a in ss if a['role']=='host')

    def wait(predicate,timeout=180):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            if (out/'STOP').exists():raise KeyboardInterrupt('Stop file requested')
            if any(p.poll() is not None for p in s.processes):raise RuntimeError('A game process exited unexpectedly')
            ss=s.states()
            if len(ss)==4 and predicate(ss):return ss
            time.sleep(.5)
        raise RuntimeError('Timed out waiting for a game-state condition in '+stage)

    def ack(role,action,**kw):
        cid=s.command(role,action,**kw)
        return wait(lambda ss:any(a['role']==role and a.get('last_command_id')==cid for a in ss),60)

    def rpc(method,**kw):
        r=subprocess.run([sys.executable,'-I',str(s.ROOT/'tools/coop-anything/tools/chaos/chaos.py'),'call','--rpc-port',str(metadata['rpc']),method,json.dumps(kw)],capture_output=True,text=True,check=True,timeout=15)
        return json.loads(r.stdout)

    def health():
        if (out/'STOP').exists():raise KeyboardInterrupt('Stop file requested')
        if any(p.poll() is not None for p in s.processes):raise RuntimeError('A game process exited unexpectedly')
        ss=s.states()
        if len(ss)!=4 or not s.ready(ss):raise RuntimeError('Four-client world is no longer ready')
        if any(time.time()-(s.user_dir(role)/'nn_state.json').stat().st_mtime>20 for role in s.roles):raise RuntimeError('A client stopped reporting for 20 seconds')
        if not all(a.get('audio_muted') for a in ss):raise RuntimeError('A test client is not muted')
        h=host(ss)
        report.setdefault('merged_record_moves',{})
        for a in ss:
            report['merged_record_moves'][a['role']]=max(report['merged_record_moves'].get(a['role'],0),a.get('merged_record_moves',0))
        if h['conveyors']!=belts or abs(h['cargo_strands']-strands)>.01:raise RuntimeError(f'Factory conservation mismatch: belts={h["conveyors"]}, strands={h["cargo_strands"]}, expected={strands}')
        bad=[{'role':a['role'],'duplicates':a['duplicate_belt_ids'],'examples':a.get('duplicate_examples',[])} for a in ss if a['duplicate_belt_ids']]
        if bad:
            (out/'failure-state.json').write_text(json.dumps(ss,indent=2),encoding='utf-8')
            raise RuntimeError('Duplicate conveyor record identity: '+json.dumps(bad))
        if h.get('belt_strands',0)<strands*.5:raise RuntimeError('Moving cargo dropped below half the fixture quantity')
        usage=[]
        for role,p in zip(s.roles,s.processes):
            proc=psutil.Process(p.pid)
            rss=proc.memory_info().rss/1048576
            report['peak_rss_mib'][role]=max(rss,report['peak_rss_mib'].get(role,0))
            usage.append({'role':role,'rss_mib':rss,'cpu_seconds':sum(proc.cpu_times()[:2])})
        if sum(a['rss_mib'] for a in usage)>min(12288,psutil.virtual_memory().total/1048576*.65):raise RuntimeError('Test memory budget exceeded; stopping owned game processes')
        report['samples']+=1
        metrics.write(json.dumps({'time':time.time(),'states':ss,'processes':usage})+'\n')
        return ss

    def checkpoint():
        ss=ack('host','save',disable_autosave=True)
        file=s.user_dir('host')/'saves/slot_0.dat'
        if not file.exists():raise RuntimeError('Checkpoint was not written')
        return host(ss),s.hay_values('host'),hashlib.sha256(file.read_bytes()).hexdigest()

    def restore_check(expected,heights):
        ss=wait(s.hay_consistent,240)
        for a in ss:
            if a['seed']!=expected['seed'] or abs(a['money']-expected['money'])>.01 or a['tech']!=expected['tech']:
                raise RuntimeError('Restored shared state differs from checkpoint')
            if a['broom_owned']!=(a['role']=='guest1'):raise RuntimeError('Personal tool ownership changed after recovery')
        restored=s.hay_values('host')
        if len(restored)!=len(heights) or max(abs(a-b) for a,b in zip(restored,heights))>.0021:raise RuntimeError('Saved field did not restore')
        health()
        ack('host','stress_view')

    def reload_world():
        expected,heights,_=checkpoint()
        s.command('host','menu')
        wait(lambda ss:all(not a['world'] for a in ss),90)
        s.command('host','reload')
        restore_check(expected,heights)
        report['save_load_cycles']+=1
        note('SAVE_LOAD_PASS',cycle=report['save_load_cycles'])

    def crash_recovery():
        expected,heights,digest=checkpoint()
        s.command('host','money')
        wait(lambda ss:s.ready(ss) and all(abs(a['money']-expected['money']-17)<.01 for a in ss),60)
        (out/'host-before-crash.log').write_bytes((out/'host.log').read_bytes())
        old=s.processes.pop(0)
        old.terminate()
        old.wait(timeout=15)
        wait(lambda ss:all(not a['world'] for a in ss if a['role']!='host'),100)
        if hashlib.sha256((s.user_dir('host')/'saves/slot_0.dat').read_bytes()).hexdigest()!=digest:raise RuntimeError('Crash changed checkpoint bytes')
        os.environ['NEEDLENET_RESTORE']='1'
        s.launch('host')
        s.processes.insert(0,s.processes.pop())
        time.sleep(5)
        for role in s.roles[1:]:s.command(role,'rejoin')
        restore_check(expected,heights)
        note('HOST_CRASH_RECOVERY_PASS',unsaved_money_rolled_back=17)

    try:
        persist()
        report['runtime_belts_sha256']=hashlib.sha256((s.GAME/'mods/multiplayer/mp_belts.gd').read_bytes()).hexdigest()
        report['driver_sha256']=hashlib.sha256((s.ROOT/'tests/session_test.gd').read_bytes()).hexdigest()
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:probe.bind(('127.0.0.1',27841))
        source_runtime=s.ROOT/'mods/multiplayer'
        if not source_runtime.is_dir():source_runtime=s.ROOT/'public/NeedleNet/mods/multiplayer'
        if not source_runtime.is_dir():raise RuntimeError('Runtime source directory not found')
        for source in source_runtime.rglob('*'):
            if source.is_file() and (s.GAME/'mods/multiplayer'/source.relative_to(source_runtime)).read_bytes()!=source.read_bytes():raise RuntimeError('Lab runtime differs from the current public source')
        chaos=s.ROOT/'tools/coop-anything/tools/chaos/chaos.py'
        info=out/'relay.json'
        relay=subprocess.Popen([sys.executable,'-I',str(chaos),'relay','--target','127.0.0.1:27841','--profile','lan','--seed','4242','--info-file',str(info)],stdout=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW)
        end=time.monotonic()+15
        while not info.exists():
            if relay.poll() is not None or time.monotonic()>end:raise RuntimeError('Relay did not start')
            time.sleep(.1)
        metadata=json.loads(info.read_text())
        os.environ['NEEDLENET_CONNECT_PORT']=str(metadata['listen'])
        for role in s.roles:
            s.launch(role)
            psutil.Process(s.processes[-1].pid).nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
            time.sleep(2 if role=='host' else .5)
        wait(s.ready)
        note('FOUR_MUTED_CLIENTS_READY')
        ack('host','fund')
        wait(lambda ss:s.ready(ss) and all(a['money']==100000 for a in ss))
        ack('guest1','buy_tech')
        wait(lambda ss:s.ready(ss) and all(len(a['tech'])>1 for a in ss) and len({json.dumps(a['tech'],sort_keys=True) for a in ss})==1)
        ack('host','grant_guest')
        wait(lambda ss:s.ready(ss) and all(a['broom_owned']==(a['role']=='guest1') for a in ss))
        note('SHARED_TECH_PERSONAL_TOOL_PASS')
        checkpoint()
        stage='machine probes'
        ack('host','production_setup')
        groups=['compressors','pulpers','papers','briquette_presses','wrappers','pelletizers']
        wait(lambda ss:s.ready(ss) and all(all(len(a['machines'].get(g,[]))==1 for g in groups) for a in ss),120)
        ack('host','production_supply')
        fixtures=[('add_compressor','hay_wad','_mouth'),('add_pulper','hay_wad','_mouth'),('add_paper','hay_pulp','_mouth'),('add_briquette','hay_wad','port_wad'),('add_wrapper','hay_bale','_mouth'),('add_pelletizer','hay_wad','_mouth')]
        for index,(name,kind,port) in enumerate(fixtures):ack('host','production_feed',machine=index,kind=kind,port=port,count=4,strands=120,native_batch=True)
        ack('host','production_feed',machine=3,kind='eco_brick',port='port_brick',native_batch=True)
        until=time.monotonic()+(15 if args.smoke else 90)
        while time.monotonic()<until:
            if any(p.poll() is not None for p in s.processes):raise RuntimeError('Game exited during machine probes')
            time.sleep(2)
        h=host(s.states())
        for name,_,_ in fixtures:
            events={k:v for k,v in h.get('production_events',{}).items() if k.startswith(name+':')}
            report['machine_probes'][name]={'status':'OUTPUT_OBSERVED' if sum(events.values()) else 'NOT_PROVEN','events':events}
        (out/'machine-states.json').write_text(json.dumps(s.states(),indent=2),encoding='utf-8')
        note('MACHINE_PROBES_RECORDED',results=report['machine_probes'])
        # Discard production fixtures before quantity-conservation testing.
        s.command('host','menu')
        wait(lambda ss:all(not a['world'] for a in ss),90)
        s.command('host','reload')
        wait(s.hay_consistent,240)
        stage='factory setup'
        belts=32 if args.smoke else 256
        count=256 if args.smoke else 4096
        strands=count*50
        ack('host','stress_view')
        ack('host','stress_factory',belts=belts,cargo=count,loops=True)
        wait(lambda ss:s.ready(ss) and host(ss)['factory_job']=='done' and all(a['conveyors']==belts and a.get('belt_strands',0)>=strands*.5 for a in ss),180)
        health()
        reload_world()
        stage='long soak'
        soak_start=time.monotonic()
        finish=soak_start+args.minutes*60
        next_cycle=soak_start+(30 if args.smoke else 900)
        next_action=soak_start+(15 if args.smoke else 300)
        next_profile=soak_start+(20 if args.smoke else 600)
        next_heartbeat=soak_start
        crash_done=False
        actions=0
        profile='bad_wifi'
        rpc('set_profile',profile=profile)
        note('SOAK_STARTED',minutes=args.minutes,belts=belts,physical_objects=count,strands=strands)
        while time.monotonic()<finish:
            ss=health()
            now=time.monotonic()
            if now>=next_action:
                before=host(ss)['money']
                ack('guest2','money')
                wait(lambda ss:s.ready(ss) and all(abs(a['money']-before-17)<.01 for a in ss),60)
                before_hay=host(s.states())['hay_sum']
                ack('guest2','dig')
                wait(lambda ss:s.hay_consistent(ss) and host(ss)['hay_sum']<before_hay-.1,90)
                ack('guest1','chat',text=f'Long test message {actions}')
                wait(lambda ss:s.ready(ss) and all(f'Long test message {actions}' in str(a['chat']) for a in ss),60)
                ack('guest3','leave')
                wait(lambda ss:host(ss)['players']==3,60)
                ack('guest3','rejoin')
                wait(s.hay_consistent,180)
                actions+=1
                note('ACTIVITY_AND_REJOIN_PASS',cycle=actions)
                next_action=time.monotonic()+(90 if args.smoke else 300)
            if now>=next_profile:
                profile='bad_wifi' if profile=='lan' else 'lan'
                rpc('set_profile',profile=profile)
                note('NETWORK_PROFILE',profile=profile)
                next_profile=time.monotonic()+(60 if args.smoke else 600)
            if not crash_done and now-soak_start>=args.minutes*30:
                rpc('set_profile',profile='lan')
                profile='lan'
                crash_recovery()
                crash_done=True
            if now>=next_cycle:
                reload_world()
                next_cycle=time.monotonic()+(120 if args.smoke else 900)
            if now>=next_heartbeat:
                note('PROGRESS',soak_minutes=round((time.monotonic()-soak_start)/60,1),remaining_minutes=round(max(0,finish-time.monotonic())/60,1),samples=report['samples'])
                next_heartbeat=time.monotonic()+60
            sleep_started=time.monotonic()
            time.sleep(3 if args.smoke else 10)
            if time.monotonic()-sleep_started>45:
                raise RuntimeError('Unobserved pause over 45 seconds (sleep or scheduling stall); long-session evidence is incomplete')
        report['soak_elapsed_minutes']=(time.monotonic()-soak_start)/60
        rpc('set_profile',profile='lan')
        reload_world()
        wait(s.hay_consistent)
        health()
        stage='graceful shutdown'
        for role,p in zip(s.roles[1:],s.processes[1:]):
            s.command(role,'quit_test')
            if p.wait(timeout=30)!=0:raise RuntimeError(role+' did not exit cleanly')
        s.command('host','quit_test')
        if s.processes[0].wait(timeout=30)!=0:raise RuntimeError('Host did not exit cleanly')
        for logfile in out.glob('*.log'):
            if 'SCRIPT ERROR:' in logfile.read_text(encoding='utf-8-sig',errors='replace'):raise RuntimeError('Script error found in '+logfile.name)
        note('GRACEFUL_SHUTDOWN_PASS')
        report['status']='SMOKE_PASS' if args.smoke else 'PASS_WITH_COVERAGE_GAPS'
    except KeyboardInterrupt:
        report.update(status='STOPPED',stage=stage,error='Test cancelled; only owned test processes are stopped.')
    except Exception as error:
        report.update(status='FAIL',stage=stage,error=str(error),traceback=traceback.format_exc())
    finally:
        if relay and relay.poll() is None:
            try:(out/'relay-stats.json').write_text(json.dumps(rpc('stats'),indent=2),encoding='utf-8')
            except Exception:pass
        for p in s.processes:
            if p.poll() is None:p.terminate()
        for p in s.processes:
            try:p.wait(timeout=15)
            except subprocess.TimeoutExpired:p.kill();p.wait(timeout=10)
        if relay and relay.poll() is None:relay.terminate()
        if relay:relay.wait(timeout=15)
        metrics.close()
        report['elapsed_minutes']=(time.monotonic()-started)/60
        if soak_start is not None:report['soak_elapsed_minutes']=(time.monotonic()-soak_start)/60
        persist()
        summary={k:report.get(k) for k in ['run_id','status','stage','error','requested_minutes','soak_elapsed_minutes','save_load_cycles','samples','merged_record_moves','coverage_gaps','output']}
        summary['machine_probes']={name:value['status'] for name,value in report['machine_probes'].items()}
        block='BEGIN_NEEDLENET_LONG_TEST_RESULT\n'+json.dumps(summary,ensure_ascii=False,indent=2)+'\nEND_NEEDLENET_LONG_TEST_RESULT\n'
        (out/'SEND-TO-CODEX.txt').write_text(block,encoding='utf-8')
        (s.ROOT/'local/LONG-TEST-RESULT.txt').write_text(block,encoding='utf-8')
        print('\n'+block,flush=True)
        print('Copy the BEGIN...END block here, or send SEND-TO-CODEX.txt.',flush=True)
    return 0 if report['status'] in ['SMOKE_PASS','PASS_WITH_COVERAGE_GAPS'] else 1


if __name__=='__main__':
    raise SystemExit(main())
