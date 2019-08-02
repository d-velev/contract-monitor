<template>
  <div id="app">
    <div>
      <ae-input-plain placeholder="Contract address" v-model="contractAddress" />
    </div>
    <div>
      <ae-button face="round" fill="primary" @click="submit">Monitor</ae-button>
    </div>
    <div id="content">
      <div id="calls-by-dates-chart" class="line-chart"><line-chart :chartData="callsByDates"/></div>
      <div id="unique-users-by-dates-chart" class="line-chart"><line-chart :chartData="uniqueUsersByDates"/></div>
      <div id="amounts-by-dates-chart" class="line-chart"><line-chart :chartData="amountsByDates"/></div>
      <span>Events:</span>
      <div id="event-logs"></div>
    </div>
  </div>
</template>

<script>
import { AeInputPlain, AeButton } from "@aeternity/aepp-components"

import LineChart from './LineChart.js'

let phoenix = require('phoenix-js')
let axios = require('axios');
let moment = require('moment')

export default {
  name: 'app',
  components: {
    socket: null,
    channel: null,
    AeInputPlain,
    AeButton,
    LineChart
  },
  data() {
    return {
      contractAddress: "",
      callsByDates: {},
      uniqueUsersByDates: {},
      uniqueUsersForToday: [],
      amountsByDates: {}
    }
  },
  created: function(){
    this.socket = new phoenix.Socket('ws://localhost:4000/socket')
    this.channel = this.socket.channel('room:notifications')

    this.socket.connect()

    this.channel.join()
    .receive('ok', ({messages}) => console.log('Successful join'))
    .receive('error', ({reason}) => console.log('Failed join', reason))
    .receive('timeout', () => console.log('Timeout when joining'))

    let that = this;
    this.channel.on('new_call', function(msg) {
        that.callsByDates.datasets[0].data[that.callsByDates.datasets[0].data.length - 1]++
        var keys = that.callsByDates.labels;
        var values = that.callsByDates.datasets[0].data

        var result = {};
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("callsByDates", result)

        if(!that.uniqueUsersForToday.includes(msg.tx.caller_id)) {
            that.uniqueUsersByDates.datasets[0].data[that.uniqueUsersByDates.datasets[0].data.length - 1]++
        }
        values = that.uniqueUsersByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("uniqueUsers", result)

        that.amountsByDates.datasets[0].data[that.amountsByDates.datasets[0].data.length - 1] += msg.tx.amount
        values = that.amountsByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("amountsByDates", result)
      }
    )

    this.channel.on('new_event', function(events) {
      events.events.forEach(function(event) {
        console.log(event)
        document.getElementById('event-logs').innerText += event + '\n'
      })
    })

  },
  destroyed: function() {
    this.socket.disconnect(function(){
      console.log('Disconnected')
    }, 1000, 'disconnect');
  },
  methods: {
    newDate(days) {
      return moment().add(days, 'd');
    },
    submit() {
      document.getElementById('content').style.visibility = "visible"
      document.getElementById('event-logs').innerText = ""
      let that = this
      axios.get(`http://localhost:4000/set-contract/${this.contractAddress}/edit`)
      axios.get(`https://testnet.mdw.aepps.com/middleware/contracts/transactions/address/${this.contractAddress}`)
      .then(async function(res){
        let block_hashes = []
        for(let i = 1; i < res.data.transactions.length; i++){
          block_hashes.push(res.data.transactions[i].block_hash)
        }

        let unique_hashes = block_hashes.filter( function(value, index, self) {
            return self.indexOf(value) === index;
        })

        let header_promises = []
        for(let i = 0; i < unique_hashes.length; i++){
          header_promises.push(axios.get(`https://sdk-testnet.aepps.com/v2/micro-blocks/hash/${unique_hashes[i]}/header`))
        }
        let block_timestamps = {}
        let calls_by_dates = {}
        let unique_users_by_dates = {}
        let unique_user_count_by_dates = {}
        let amounts_by_dates = {}
        Promise.all(header_promises).then(async function(headers){
          headers.forEach(function(el){
            block_timestamps[el.data.hash] = el.data.time
          })

          for (let i = 29; i >= 0; i--) {
            let d = new Date();
            d.setDate(d.getDate() - i);
            let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()
            calls_by_dates[key] = 0
            unique_users_by_dates[key] = []
            unique_user_count_by_dates[key] = 0
            amounts_by_dates[key] = 0
          }

          let today = new Date();
          let n_days_back_date = new Date();
          n_days_back_date.setDate(n_days_back_date.getDate() - 29)
          res.data.transactions.shift();
          let filtered_transactions = res.data.transactions.filter(function(value, index, self) {
            return block_timestamps[value.block_hash] >= n_days_back_date.getTime()
              && block_timestamps[value.block_hash] <= today.getTime();
          })

          for(let i = 0; i < filtered_transactions.length; i++){
            let d = new Date(block_timestamps[filtered_transactions[i].block_hash])
            let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()
            calls_by_dates[key]++

            if(!unique_users_by_dates[key].includes(filtered_transactions[i].tx.caller_id)) {
              unique_users_by_dates[key].push(filtered_transactions[i].tx.caller_id)
              unique_user_count_by_dates[key]++;
            }

            if(d.getMonth() == today.getMonth()
              && d.getDate() == today.getDate()
              && d.getFullYear() == today.getFullYear()
              && !that.uniqueUsersForToday.includes(filtered_transactions[i].tx.caller_id)) {
                that.uniqueUsersForToday.push(filtered_transactions[i].tx.caller_id)
              }

            amounts_by_dates[key] += filtered_transactions[i].tx.amount
          }

          that.fillData("callsByDates", calls_by_dates)
          that.fillData("uniqueUsersByDates", unique_user_count_by_dates)
          that.fillData("amountsByDates", amounts_by_dates)
        })
      })
    },
    fillData (key, data) {
      this[key] = {
        labels: Object.keys(data),
        datasets: [{
           data: Object.values(data),
           label: key,
           borderWidth: 2,
           borderColor: "#3e95cd",
           fill: false,
           pointRadius: 0
        }]
      }
    }
  }
}
</script>

<style>
#content{
  visibility: hidden;
}
.ae-input-plain{
  margin-bottom: 20px;
  text-align: center;
  width: 40% !important;

}
.ae-button{
  margin-bottom: 20px;
}
.line-chart{
  width: 33%;
  float: left;
  margin: 0 auto;
}
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
