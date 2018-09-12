/**
 * Modifications Copyright 2017 HUAWEI
 * Copyright 2016 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an 'AS IS' BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

'use strict';

if (global && global.hfc) {
    global.hfc.config = undefined;
}

require('nconf').reset();
const utils = require('fabric-client/lib/utils.js');
//const logger = utils.getLogger('E2E create-channel');

//const tape = require('tape');
//const _test = require('tape-promise');
//const test = _test(tape);

const Client = require('fabric-client');
//const util = require('util');
const fs = require('fs');
//const grpc = require('grpc');

const testUtil = require('./util.js');
const commUtils = require('../comm/util');
const e2eUtils = require('./e2eUtils.js');

/**
 * Create the channels located in the given configuration file.
 * @param {string} config_path The path to the Fabric network configuration file.
 * @return {Promise} The return promise.
 */
function run(config_path) {
    Client.addConfigFile(config_path);
    const fabric = Client.getConfigSetting('fabric');
    const channels = fabric.channel;
    let client = new Client();
    let tlsInfo = null;
    if(!channels || channels.length === 0) {
        return Promise.reject(new Error('No channel information found'));
    }
    let channel_name = 'mychannel8';
    return new Promise(function(resolve, reject) {
        const t = global.tapeObj;
        let ORGS = fabric.network;
        let caRootsPath = ORGS.orderer.tls_cacerts;
        let data = fs.readFileSync(commUtils.resolvePath(caRootsPath));
        let caroots = Buffer.from(data).toString();
        utils.setConfigSetting('key-value-store', 'fabric-client/lib/impl/FileKeyValueStore.js');
        let org = ORGS.org1.name;
        let config = null;
        let signatures = [];
        let orderer = null;
        return e2eUtils.tlsEnroll('org1')
            .then((enrollment)=>{
                t.pass('Successfully retrieved TLS certificate');
                tlsInfo = enrollment;

                return Client.newDefaultKeyValueStore({path: testUtil.storePathForOrg(org)});
            }).then((store) => {
                client.setStateStore(store);
                let cryptoSuite = Client.newCryptoSuite();
                cryptoSuite.setCryptoKeyStore(Client.newCryptoKeyStore({path: testUtil.storePathForOrg(org)}));
                client.setCryptoSuite(cryptoSuite);
                t.comment(tlsInfo.key);

                // use the config update created by the configtx tool
                let envelope_bytes = fs.readFileSync(commUtils.resolvePath('network/fabric/mynetwork/mychannel8.tx'));
                config = client.extractChannelConfig(envelope_bytes);
                t.comment(config);
                t.pass('Successfull extracted the config update from the configtx envelope');

                return testUtil.getSubmitter(client, true /*get the org admin*/, 'org1');
            }).then((admin) => {
                t.pass('Successfully enrolled user \'admin\' for org1');

                // sign the config
                let signature = client.signChannelConfig(config);
                // convert signature to a storable string
                // fabric-client SDK will convert back during create
                let string_signature = signature.toBuffer().toString('hex');
                t.pass('Successfully signed config update');
                // collect signature from org1 admin
                signatures.push(string_signature);
                return testUtil.getSubmitter(client, true /*get the org admin*/, 'org2');
            }).then((admin)=>{
                t.pass('Successfully enrolled user \'admin\' for org2');
                // sign the config
                let signature = client.signChannelConfig(config);
                t.pass('Successfully signed config update');

                // collect signature from org2 admin
                signatures.push(signature);

                // return testUtil.getOrderAdminSubmitter(client, t);
                return testUtil.getSubmitter(client, true /*get the org admin*/, 'org3');
            }).then((admin)=>{
                t.pass('Successfully enrolled user \'admin\' for org3');
                // sign the config
                let signature = client.signChannelConfig(config);
                t.pass('Successfully signed config update');

                // collect signature from org2 admin
                signatures.push(signature);

                // return testUtil.getOrderAdminSubmitter(client, t);
                return testUtil.getSubmitter(client, true /*get the org admin*/, 'org4');
            }).then((admin)=>{
                t.pass('Successfully enrolled user \'admin\' for org4');
                // sign the config
                let signature = client.signChannelConfig(config);
                t.pass('Successfully signed config update');

                // collect signature from org2 admin
                signatures.push(signature);
                // return testUtil.getOrderAdminSubmitter(client, t);
                return testUtil.getSubmitter(client, true /*get the org admin*/, 'org5');
            }).then((admin)=>{
                t.pass('Successfully enrolled user \'admin\' for org5');

                // sign the config
                let signature = client.signChannelConfig(config);
                t.pass('Successfully signed config update');
                // collect signature from org2 admin
                signatures.push(signature);
                return testUtil.getOrderAdminSubmitter(client, t);
            }).then((nothing)=>{
                orderer = client.newOrderer(
                    ORGS.orderer.url,
                    {
                        'pem': caroots,
                        'clientCert': tlsInfo.certificate,
                        'clientKey': tlsInfo.key,
                        'ssl-target-name-override': ORGS.orderer['server-hostname'],
                        'grpc-max-send-message-length': 1024 * 1024 * 10,
                        'grpc.max_send_message_length': 1024 * 1024 * 10,
                        'grpc.max_receive_message_length': 8 * 1024 * 1024
                    }
                );
                // let's try to get some info from the orderer
                // Get the system channel config decoded
                let sys_channel = client.newChannel('testchainid');
                sys_channel.addOrderer(orderer);
                return sys_channel.getChannelConfigFromOrderer();
            }).then((config_envelope)=>{
                t.pass('Successfully received the configuration');

                // build up the create request
                let tx_id = client.newTransactionID();
                let request = {
                    config: config,
                    signatures : signatures,
                    name : channel_name,
                    orderer : orderer,
                    txId  : tx_id
                };
                // send create request to orderer
                return client.createChannel(request);
            }, Promise.resolve())
            .then(()=>{
                t.comment('Sleep 5s......');
                return commUtils.sleep(5000);
            })
            .then(() => {
                return resolve();
            })
            .catch((err) => {
                t.fail('Failed to create channels ' + (err.stack?err.stack:err));
                return reject(new Error('Fabric: Create channel failed'));
            });
    });
}

module.exports.run = run;


