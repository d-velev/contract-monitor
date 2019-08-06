<template>
  <div id="app">
    <h1>Contract monitor</h1>
    <div>
      <ae-input-plain placeholder="Contract address" v-model="contractAddress" />
    </div>
    <div>
      <ae-button face="round" fill="primary" @click="displayCharts(true)">Monitor</ae-button>
    </div>
    <div id="content">
      <div id="selectors">
        <ae-check v-model="chartDays" value="3" type="radio" @change="displayCharts(false)">3 days</ae-check>
        <ae-check v-model="chartDays" value="7" type="radio" @change="displayCharts(false)">7 days</ae-check>
        <ae-check v-model="chartDays" value="30" type="radio" @change="displayCharts(false)">30 days (default)</ae-check>
      </div>
      <div id="calls-by-dates-chart" class="line-chart"><line-chart :chartData="callsByDates" :options="callsByDates.options"/></div>
      <div id="unique-users-by-dates-chart" class="line-chart"><line-chart :chartData="uniqueUsersByDates" :options="uniqueUsersByDates.options"/></div>
      <div id="amounts-by-dates-chart" class="line-chart"><line-chart :chartData="amountsByDates" :options="amountsByDates.options"/></div>
      <div>
        <h2>Events </h2>
        <table id="events">
          <thead>
            <tr>
              <th id="topics">
                Topics
              </th>
              <th>
                Data
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in events" v-bind:key="e.data">
              <td>
                {{e.topics}}
              </td>
              <td>
                {{e.data}}
              </td>
            </tr>
          </tbody>
      </table>
    </div>
    </div>
  </div>
</template>

<script>
import { AeInputPlain, AeButton, AeCheck } from "@aeternity/aepp-components"

import LineChart from './LineChart.js'

let phoenix = require('phoenix-js')
let axios = require('axios')

export default {
  name: 'app',
  components: {
    AeInputPlain,
    AeButton,
    AeCheck,
    LineChart
  },
  data() {
    return {
      socket: null,
      channel: null,
      contractAddress: "",
      chartDays: 30,
      callsByDates: {},
      uniqueUsersByDates: {},
      uniqueUsersForToday: [],
      amountsByDates: {},
      events: []
    }
  },
  created: function(){
    this.socket = new phoenix.Socket('ws://localhost:4000/socket')
    this.channel = this.socket.channel('room:notifications')

    this.socket.connect()

    this.channel.join()

    let that = this;
    this.channel.on('new_call', function(msg) {
        that.callsByDates.datasets[0].data[that.callsByDates.datasets[0].data.length - 1]++
        var keys = that.callsByDates.labels;
        var values = that.callsByDates.datasets[0].data

        var result = {};
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("callsByDates", result)

        if(!that.uniqueUsersForToday.includes(msg.tx.caller_id)) {
            that.uniqueUsersByDates.datasets[0].data[that.uniqueUsersByDates.datasets[0].data.length - 1]++;
            that.uniqueUsersForToday.push(msg.tx.caller_id);
        }

        values = that.uniqueUsersByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("uniqueUsersByDates", result)

        that.amountsByDates.datasets[0].data[that.amountsByDates.datasets[0].data.length - 1] += msg.tx.amount / 1000000000000000000
        values = that.amountsByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("amountsByDates", result)
      }
    )

    this.channel.on('new_event', function(events) {
      that.events = that.events.concat(events.events)
    })

  },
  destroyed: function() {
    this.socket.disconnect(()=>{}, 1000, 'disconnect');
  },
  methods: {
    displayCharts(clearLogs) {
      if(this.contractAddress == "") return;

      this.showCharts();

      let that = this
      axios.get(`http://localhost:4000/set-contract/${this.contractAddress}/edit`);
      axios.get(`https://testnet.mdw.aepps.com/middleware/contracts/transactions/address/${this.contractAddress}`)
      .then(async function(res){
        res.data.transactions.shift();

        let block_hashes = that.getUniqueBlockHashes(res.data.transactions);

        let header_promises = that.generateMicroBlockHeaderPromises(block_hashes);

        let block_timestamps = {};
        let chart_data = {
          calls_by_dates: {},
          unique_users_by_dates: {},
          unique_user_count_by_dates: {},
          amounts_by_dates: {}
        };
        Promise.all(header_promises).then(async function(headers){
          headers.forEach(function(el){
            block_timestamps[el.data.hash] = el.data.time;
          });

          that.populateChartDataDays(chart_data);

          let filtered_transactions =
            that.filterTransactionsByCurrentTimeFrame(res.data.transactions, block_timestamps);

          for(let i = 0; i < filtered_transactions.length; i++){
            let d = new Date(block_timestamps[filtered_transactions[i].block_hash])
            let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()
            chart_data.calls_by_dates[key]++

            if(!chart_data.unique_users_by_dates[key].includes(filtered_transactions[i].tx.caller_id)) {
              chart_data.unique_users_by_dates[key].push(filtered_transactions[i].tx.caller_id)
              chart_data.unique_user_count_by_dates[key]++;
            }

            that.addUniqueUserForToday(d, filtered_transactions[i].tx.caller_id);

            chart_data.amounts_by_dates[key] += filtered_transactions[i].tx.amount / 1000000000000000000
          }

          that.fillData("callsByDates", chart_data.calls_by_dates)
          that.fillData("uniqueUsersByDates", chart_data.unique_user_count_by_dates)
          that.fillData("amountsByDates", chart_data.amounts_by_dates)
        })
      })

      if(clearLogs) {
        this.events = []
      }
    },
    showCharts() {
      document.getElementsByTagName('body')[0].style.overflow = "scroll"
      document.getElementById('content').style.visibility = "visible"
    },
    getUniqueBlockHashes(txs) {
      return txs.map(function(tx) {
          return tx.block_hash;
        })
        .filter(function(tx, index, self){
            return self.indexOf(tx) === index;
        })
    },
    generateMicroBlockHeaderPromises(block_hashes) {
      return block_hashes.map(function(block_hash) {
          return axios.get(`https://sdk-testnet.aepps.com/v2/micro-blocks/hash/${block_hash}/header`)
        });
    },
    populateChartDataDays(chart_data) {
      for (let i = this.chartDays - 1; i >= 0; i--) {
        let d = new Date();
        d.setDate(d.getDate() - i);
        let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()

        chart_data.calls_by_dates[key] = 0
        chart_data.unique_users_by_dates[key] = []
        chart_data.unique_user_count_by_dates[key] = 0
        chart_data.amounts_by_dates[key] = 0
      }
    },
    filterTransactionsByCurrentTimeFrame(txs, block_timestamps) {
      let today = new Date();
      let n_days_back_date = new Date();
      n_days_back_date.setDate(n_days_back_date.getDate() - this.chartDays - 1)

      return txs.filter(function(value) {
        return block_timestamps[value.block_hash] >= n_days_back_date.getTime()
          && block_timestamps[value.block_hash] <= today.getTime();
      })
    },
    addUniqueUserForToday(current_date, caller_id) {
      let today = new Date();
      if(current_date.getMonth() == today.getMonth()
        && current_date.getDate() == today.getDate()
        && current_date.getFullYear() == today.getFullYear()
        && !this.uniqueUsersForToday.includes(caller_id)) {
          this.uniqueUsersForToday.push(caller_id)
        }
    },
    fillData(key, data) {
      this[key] = {
        labels: Object.keys(data),
        datasets: [{
           data: Object.values(data),
           borderWidth: 2,
           borderColor: "#FF0D6A",
           fill: false,
           pointRadius: 0,
           hitRadius: 5
        }],
        options: {
          legend: {
            display: false
          },
          title: {
            display: true,
            text: this.keyToLabel(key)
          },
          scales: {
              yAxes: [{
                  ticks: {
                      beginAtZero: true
                  }
              }]
          }
        }
      }
    },
    keyToLabel(key) {
      let label = ""
      switch(key){
        case "callsByDates":
          label = "Calls"
          break;
        case "uniqueUsersByDates":
          label = "Unique users"
          break;
        case "amountsByDates":
          label = "Volume (æ tokens)"
          break;
      }

      return label;
    }
  }
}
</script>

<style>
body{
  overflow: hidden;
}
#content{
  visibility: hidden;
}
#events{
  margin: 0 auto 75px;
  width: 50%;
}
#selectors{
  margin: 10px 0 10px;
}
#topics{
  width: 50%;
}
.ae-input-plain{
  margin-bottom: 20px;
  text-align: center;
  width: 40% !important;

}
.ae-button{
  margin-bottom: 20px;
}
.ae-check-button {
  padding-left: 2.5rem !important;
  padding-right: 3rem !important;
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
